import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerLoading.rectangular({
    Key? key,
    this.width = double.infinity,
    required this.height,
    this.baseColor = const Color(0xFFCCCCCC),
    this.highlightColor = const Color(0xFFFFFFFF),
    this.shapeBorder = const RoundedRectangleBorder(),
  }) : super(key: key);

  const ShimmerLoading.circular({
    Key? key,
    required this.width,
    required this.height,
    this.baseColor = const Color(0xFFCCCCCC),
    this.highlightColor = const Color(0xFFFFFFFF),
    this.shapeBorder = const CircleBorder(),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(seconds: 10),
        child: Container(
          width: width,
          height: height,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: shapeBorder,
          ),
        ),
      );
}

class ListShimmer extends StatelessWidget {
  const ListShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              const ShimmerLoading.circular(width: 40, height: 40),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading.rectangular(
                      height: 14,
                      width: MediaQuery.of(context).size.width * 0.4,
                      shapeBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ShimmerLoading.rectangular(
                      height: 10,
                      width: MediaQuery.of(context).size.width * 0.2,
                      shapeBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              ShimmerLoading.rectangular(
                height: 18,
                width: 60,
                shapeBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Header Shimmer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
            decoration: const BoxDecoration(
              color: Color(0xFF009639),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(35),
                bottomRight: Radius.circular(35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const ShimmerLoading.circular(
                      width: 50, 
                      height: 50,
                      baseColor: Colors.white24,
                      highlightColor: Colors.white54,
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerLoading.rectangular(
                          height: 12, width: 80, 
                          baseColor: Colors.white24, highlightColor: Colors.white54,
                          shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 5),
                        ShimmerLoading.rectangular(
                          height: 16, width: 120, 
                          baseColor: Colors.white24, highlightColor: Colors.white54,
                          shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                  ],
                ),
                const ShimmerLoading.circular(
                  width: 35, 
                  height: 35,
                  baseColor: Colors.white24,
                  highlightColor: Colors.white54,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance Card Shimmer
                ShimmerLoading.rectangular(
                  height: 180,
                  width: double.infinity,
                  shapeBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                const SizedBox(height: 30),
                // Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerLoading.rectangular(
                      height: 20, width: 120,
                      shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Quick Actions Shimmer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(4, (index) => Column(
                    children: [
                      const ShimmerLoading.circular(width: 55, height: 55),
                      const SizedBox(height: 8),
                      ShimmerLoading.rectangular(
                        height: 12, width: 45,
                        shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ],
                  )),
                ),
                const SizedBox(height: 30),
                // Recent Activity Header
                ShimmerLoading.rectangular(
                  height: 20, width: 150,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(height: 15),
                // List Shimmer
                const ListShimmer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PageShimmer extends StatelessWidget {
  const PageShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Header Shimmer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
            decoration: const BoxDecoration(
              color: Color(0xFF009639),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(35),
                bottomRight: Radius.circular(35),
              ),
            ),
            child: Row(
              children: [
                const ShimmerLoading.circular(width: 30, height: 30, baseColor: Colors.white24, highlightColor: Colors.white54),
                const SizedBox(width: 10),
                ShimmerLoading.rectangular(
                  height: 20, width: 120, 
                  baseColor: Colors.white24, highlightColor: Colors.white54,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance Card Shimmer
                ShimmerLoading.rectangular(
                  height: 140,
                  width: double.infinity,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                const SizedBox(height: 20),
                ShimmerLoading.rectangular(
                  height: 100,
                  width: double.infinity,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                const SizedBox(height: 30),
                // Section Header
                ShimmerLoading.rectangular(
                  height: 20, width: 150,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(height: 15),
                // List Shimmer
                const ListShimmer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
