import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HealthTipsPage extends StatefulWidget {
  const HealthTipsPage({Key? key}) : super(key: key);

  @override
  State<HealthTipsPage> createState() => _HealthTipsPageState();
}

class _HealthTipsPageState extends State<HealthTipsPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _futureTips;

  final Map<int, bool> _expandedMap = {}; // Caption expanded
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;

  // Local state for likes and comments per tip
  final Map<int, ValueNotifier<bool>> _likedMap = {};
  final Map<int, ValueNotifier<int>> _likeCountMap = {};
  final Map<int, ValueNotifier<int>> _commentCountMap = {};

  @override
  void initState() {
    super.initState();
    _futureTips = fetchTips();
  }

  String formatTimeAgo(DateTime postTime) {
    final now = DateTime.now();
    final difference = now.difference(postTime);
    if (difference.inMinutes < 1) return "just now";
    if (difference.inMinutes < 60) return "${difference.inMinutes}m";
    if (difference.inHours < 24) return "${difference.inHours}h";
    if (difference.inDays < 7) return "${difference.inDays}d";
    if (difference.inDays < 30) return "${(difference.inDays / 7).floor()}w";
    if (difference.inDays < 365) return "${(difference.inDays / 30).floor()}mo";
    return "${(difference.inDays / 365).floor()}y";
  }

  Future<List<Map<String, dynamic>>> fetchTips() async {
    final res = await supabase
        .from("health_tips")
        .select()
        .order("created_at", ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // Initialize or refresh tip state
  Future<void> _initTipState(int tipId) async {
    final isLiked = await _isLikedByCurrentUser(tipId);
    final likeCount = await _getLikeCount(tipId);
    final commentCount = await _getCommentCount(tipId);

    _likedMap[tipId] = ValueNotifier<bool>(isLiked);
    _likeCountMap[tipId] = ValueNotifier<int>(likeCount);
    _commentCountMap[tipId] = ValueNotifier<int>(commentCount);
  }

  Future<bool> _isLikedByCurrentUser(int tipId) async {
    final res = await supabase
        .from("health_tips_likes")
        .select()
        .eq("tip_id", tipId)
        .eq("user_id", currentUserId!);
    return (res as List).isNotEmpty;
  }

  Future<int> _getLikeCount(int tipId) async {
    final res = await supabase
        .from("health_tips_likes")
        .select()
        .eq("tip_id", tipId);
    return (res as List).length;
  }

  Future<int> _getCommentCount(int tipId) async {
    final res = await supabase
        .from("health_tips_comments")
        .select()
        .eq("tip_id", tipId);
    return (res as List).length;
  }

  Future<void> _toggleLike(int tipId) async {
    final likedNotifier = _likedMap[tipId]!;
    final countNotifier = _likeCountMap[tipId]!;

    if (likedNotifier.value) {
      await supabase
          .from("health_tips_likes")
          .delete()
          .eq("tip_id", tipId)
          .eq("user_id", currentUserId!);
      likedNotifier.value = false;
      countNotifier.value--;
    } else {
      await supabase.from("health_tips_likes").insert({
        "tip_id": tipId,
        "user_id": currentUserId,
        "created_at": DateTime.now().toIso8601String(),
      });
      likedNotifier.value = true;
      countNotifier.value++;
    }
  }

  Future<void> _addComment(int tipId, String comment) async {
    await supabase.from("health_tips_comments").insert({
      "tip_id": tipId,
      "user_id": currentUserId,
      "comment": comment,
      "created_at": DateTime.now().toIso8601String(),
    });
    _commentCountMap[tipId]?.value++;
  }

  Future<List<Map<String, dynamic>>> _fetchComments(int tipId) async {
    final res = await supabase
        .from("health_tips_comments")
        .select()
        .eq("tip_id", tipId)
        .order("created_at", ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  void _showCommentsBottomSheet(int tipId) {
    final commentController = TextEditingController();
    final commentsNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);

    // Function to fetch comments with user info
    Future<void> _loadComments() async {
      final commentsRes = await supabase
          .from("health_tips_comments")
          .select()
          .eq("tip_id", tipId)
          .order("created_at", ascending: true);
      final commentsList = List<Map<String, dynamic>>.from(commentsRes);

      // Fetch user info for each comment
      final enrichedComments = await Future.wait(
        commentsList.map((comment) async {
          final userId = comment['user_id'];
          final userRes = await supabase
              .from("Users")
              .select("username, profileImage")
              .eq("userId", userId)
              .single();
          return {
            ...comment,
            "username": userRes['username'] ?? "Anonymous",
            "profileImage": userRes['profileImage'],
          };
        }),
      );

      commentsNotifier.value = enrichedComments;
    }

    // Load comments initially
    _loadComments();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                Expanded(
                  child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: commentsNotifier,
                    builder: (context, comments, _) {
                      if (comments.isEmpty) {
                        return const Center(child: Text("No comments yet"));
                      }
                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final username = comment['username'] ?? "Anonymous";
                          final profileImage = comment['profileImage'];
                          final text = comment['comment'] ?? "";

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: profileImage != null
                                  ? NetworkImage(profileImage)
                                  : null,
                              child: profileImage == null
                                  ? Text(username[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(username),
                            subtitle: Text(text),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: const InputDecoration(
                            hintText: "Write a comment",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          final text = commentController.text.trim();
                          if (text.isNotEmpty) {
                            // Insert new comment
                            await supabase.from("health_tips_comments").insert({
                              "tip_id": tipId,
                              "user_id": currentUserId,
                              "comment": text,
                              "created_at": DateTime.now().toIso8601String(),
                            });
                            commentController.clear();

                            // Refresh comment list in bottom sheet
                            await _loadComments();

                            // Update comment count
                            _commentCountMap[tipId]?.value++;
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureTips,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final tips = snapshot.data ?? [];
          if (tips.isEmpty)
            return const Center(child: Text("No health tips yet"));

          return ListView.builder(
            itemCount: tips.length,
            itemBuilder: (context, index) {
              final tip = tips[index];
              final tipId = tip['id'];
              final caption = tip['caption'] ?? "";
              final mediaUrl = tip['media_url'];
              final mediaType = tip['media_type'];
              final postedBy = tip['posted_by'] ?? "Anonymous";
              final isExpanded = _expandedMap[tipId] ?? false;

              // Initialize tip state if not done
              if (!_likedMap.containsKey(tipId)) {
                _initTipState(tipId);
              }

              // Caption display
              const int maxChars = 100;
              final bool isLongCaption = caption.length > maxChars;
              final displayText = isLongCaption
                  ? caption.substring(0, maxChars) + "..."
                  : caption;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[200],
                          child: Text(
                            postedBy.isNotEmpty
                                ? postedBy[0].toUpperCase()
                                : "?",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          tip['created_at'] != null
                              ? formatTimeAgo(
                                  DateTime.parse(tip['created_at']).toLocal(),
                                )
                              : "",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Caption
                      if (caption.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isExpanded ? caption : displayText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isLongCaption)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _expandedMap[tipId] = !isExpanded;
                                  });
                                },
                                child: Text(
                                  isExpanded ? "See less" : "See more",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      // Media
                      if (mediaUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: mediaType == "image"
                              ? Image.network(mediaUrl, fit: BoxFit.cover)
                              : _VideoPlayerWidget(videoUrl: mediaUrl),
                        ),
                      const SizedBox(height: 8),
                      // Like & Comment
                      Row(
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable:
                                _likedMap[tipId] ?? ValueNotifier(false),
                            builder: (context, isLiked, _) {
                              return IconButton(
                                onPressed: () => _toggleLike(tipId),
                                icon: Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                ),
                              );
                            },
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable:
                                _likeCountMap[tipId] ?? ValueNotifier(0),
                            builder: (context, count, _) => Text("$count"),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: () => _showCommentsBottomSheet(tipId),
                            icon: const Icon(Icons.comment_outlined),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable:
                                _commentCountMap[tipId] ?? ValueNotifier(0),
                            builder: (context, count, _) => Text("$count"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerWidget({required this.videoUrl});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
        }
      });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _showControls = true;
    });
    _startHideTimer();
  }

  void _seekForward() {
    final newPos = _controller.value.position + const Duration(seconds: 10);
    _controller.seekTo(newPos);
  }

  void _seekBackward() {
    final newPos = _controller.value.position - const Duration(seconds: 10);
    _controller.seekTo(newPos >= Duration.zero ? newPos : Duration.zero);
  }

  String _formatDuration(Duration position) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(position.inMinutes.remainder(60));
    final seconds = twoDigits(position.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5) {
          _controller.play();
          _startHideTimer();
        } else {
          _controller.pause();
        }
      },
      child: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
          if (_showControls) _startHideTimer();
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),

            // Center controls
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Backward
                  IconButton(
                    icon: const Icon(
                      Icons.replay_10,
                      size: 40,
                      color: Colors.white,
                    ),
                    onPressed: _seekBackward,
                  ),
                  // Play/Pause
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      size: 60,
                      color: Colors.white,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                  // Forward
                  IconButton(
                    icon: const Icon(
                      Icons.forward_10,
                      size: 40,
                      color: Colors.white,
                    ),
                    onPressed: _seekForward,
                  ),
                ],
              ),
            ),

            // Progress bar + duration
            if (_showControls)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: Colors.red,
                        bufferedColor: Colors.grey,
                        backgroundColor: Colors.black26,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_controller.value.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(_controller.value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
