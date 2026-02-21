import 'package:flutter/material.dart';

class DummyScreen extends StatelessWidget {
  const DummyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light grey body
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 1. THE HEADER WITH STACK
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF004D40), // Deep Green
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                clipBehavior: Clip.none, // ALLOWS OVERLAP
                children: [
                  // Green Background
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF004D40), Color(0xFF00695C)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(25, 60, 25, 0),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("PLAN: PRO", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                        Text("Alex Graham", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  // THE FLOATING RIBBON
                  // We anchor this to the bottom of the Stack
                  Positioned(
                    bottom: -35, // Pushes half the ribbon into the grey area
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("12", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                              Text("Groups", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          VerticalDivider(indent: 20, endIndent: 20),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("₹5.2K", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              Text("Pending", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          VerticalDivider(indent: 20, endIndent: 20),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("PRO", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                              Text("Status", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. THE BODY CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20), // Top padding of 60 to clear the ribbon
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Quick Access", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  // Dummy Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 10,
                    children: List.generate(8, (index) => Column(
                      children: [
                        Container(
                          height: 50, width: 50,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                          child: const Icon(Icons.category_outlined, color: Colors.teal),
                        ),
                        const SizedBox(height: 4),
                        const Text("Action", style: TextStyle(fontSize: 10)),
                      ],
                    )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}