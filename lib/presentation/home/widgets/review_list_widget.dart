import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/app_colors.dart';
import '../../../../domain/entities/place_review.dart';

class ReviewListWidget extends StatelessWidget {
  final List<PlaceReview> reviews;
  final void Function(PlaceReview)? onEdit;
  final void Function(PlaceReview)? onDelete;

  const ReviewListWidget({
    super.key, 
    required this.reviews,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            '아직 작성된 후기가 없어요.\n첫 후기를 남겨보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.taupe, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const Divider(color: AppColors.sand, height: 32),
      itemBuilder: (context, index) {
        return _ReviewItem(
          review: reviews[index],
          onEdit: onEdit != null ? () => onEdit!(reviews[index]) : null,
          onDelete: onDelete != null ? () => onDelete!(reviews[index]) : null,
        );
      },
    );
  }
}

class _ReviewItem extends StatefulWidget {
  final PlaceReview review;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ReviewItem({required this.review, this.onEdit, this.onDelete});

  @override
  State<_ReviewItem> createState() => _ReviewItemState();
}

class _ReviewItemState extends State<_ReviewItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Author + Stars + Date
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/app_icon3.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.review.authorNickname,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepBrown),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            // Stars
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return Icon(
                  index < widget.review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber, 
                  size: 14,
                );
              }),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('yyyy.MM.dd').format(widget.review.createdAt),
              style: const TextStyle(fontSize: 12, color: AppColors.taupe),
            ),
            if (FirebaseAuth.instance.currentUser?.uid == widget.review.authorUid)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.taupe),
                padding: EdgeInsets.zero,
                splashRadius: 20,
                onSelected: (value) {
                  if (value == 'edit' && widget.onEdit != null) widget.onEdit!();
                  if (value == 'delete' && widget.onDelete != null) widget.onDelete!();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('수정', style: TextStyle(fontSize: 14)),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('삭제', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Content Body
        LayoutBuilder(
          builder: (context, constraints) {
            final style = const TextStyle(fontSize: 14, color: AppColors.latte, height: 1.4);
            final span = TextSpan(text: widget.review.content, style: style);
            final tp = TextPainter(
              text: span,
              maxLines: 2,
              textDirection: TextDirection.ltr,
            );
            tp.layout(maxWidth: constraints.maxWidth);

            if (tp.didExceedMaxLines && !_isExpanded) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.review.content,
                    style: style,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = true),
                    child: const Text('...더보기', style: TextStyle(color: AppColors.mocha, fontWeight: FontWeight.bold, fontSize: 13)),
                  )
                ],
              );
            }

            return Text(
              widget.review.content,
              style: style,
            );
          },
        ),
      ],
    );
  }
}
