import 'package:flutter/material.dart';
import 'dart:async';
import 'services/auth_service.dart';

class PixelPetWidget extends StatefulWidget {
  final VoidCallback? onPointsChanged;

  const PixelPetWidget({
    super.key,
    this.onPointsChanged,
  });

  @override
  State<PixelPetWidget> createState() => _PixelPetWidgetState();
}

// All the moods/actions the dog can perform
enum DogAction {
  idle,
  wagging,
  jumping,
  spinning,
  sleeping,
  playing,
  petted,
  eating,
  zoomies,
}

class _PixelPetWidgetState extends State<PixelPetWidget>
    with TickerProviderStateMixin {
  int userPoints = 0;

  int petHunger = 50;
  int petHappiness = 50;
  int petEnergy = 50;
  String petName = 'Rex';

  // Animation controllers
  late AnimationController _tailWagController;
  late AnimationController _jumpController;
  late AnimationController _heartController;
  late AnimationController _spinController;
  late AnimationController _bounceController;
  late AnimationController _shakeController;
  late AnimationController _floatController;

  late Animation<double> _tailWagAnimation;
  late Animation<double> _jumpAnimation;
  late Animation<double> _heartAnimation;
  late Animation<double> _spinAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _floatAnimation;

  bool _showHearts = false;
  bool _showZzz = false;
  bool _showStars = false;
  bool _isLoading = true;
  Timer? _degradationTimer;
  Timer? _actionResetTimer;

  DogAction _currentAction = DogAction.idle;
  String _actionMessage = '';

  // Food items only
  final List<Map<String, dynamic>> foodItems = [
    {
      'id': 'bone',
      'name': 'Bone',
      'emoji': '🦴',
      'cost': 5,
      'hunger': 15,
      'happiness': 10,
      'energy': 5,
    },
    {
      'id': 'meat',
      'name': 'Meat',
      'emoji': '🥩',
      'cost': 15,
      'hunger': 30,
      'happiness': 20,
      'energy': 15,
    },
    {
      'id': 'treat',
      'name': 'Treat',
      'emoji': '🍖',
      'cost': 10,
      'hunger': 10,
      'happiness': 25,
      'energy': 10,
    },
    {
      'id': 'water',
      'name': 'Water',
      'emoji': '💧',
      'cost': 3,
      'hunger': 5,
      'happiness': 5,
      'energy': 20,
    },
  ];

  @override
  void initState() {
    super.initState();

    _tailWagController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _tailWagAnimation = Tween<double>(begin: -0.12, end: 0.12).animate(
      CurvedAnimation(parent: _tailWagController, curve: Curves.easeInOut),
    );
    _jumpAnimation = Tween<double>(begin: 0, end: -40).animate(
      CurvedAnimation(parent: _jumpController, curve: Curves.easeOut),
    );
    _heartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeOut),
    );
    _spinAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeInOut),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -18).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );
    _shakeAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
    _floatAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHearts = false);
        _heartController.reset();
      }
    });

    _tailWagController.repeat(reverse: true);
    _loadGameData();
    _startDegradationTimer();
  }

  Future<void> _loadGameData() async {
    try {
      final stats = await AuthService.getUserStats();
      setState(() {
        userPoints = stats['points'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _startDegradationTimer() {
    _degradationTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (mounted) {
        setState(() {
          petHunger = (petHunger - 2).clamp(0, 100);
          petHappiness = (petHappiness - 1).clamp(0, 100);
          petEnergy = (petEnergy - 1).clamp(0, 100);
        });
      }
    });
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _petTheDog() {
    _actionResetTimer?.cancel();
    setState(() {
      _currentAction = DogAction.petted;
      _showHearts = true;
      _actionMessage = '${petName} loves the pets! 💕';
      petHappiness = (petHappiness + 12).clamp(0, 100);
    });
    _heartController.forward(from: 0);
    _jumpController.forward().then((_) => _jumpController.reverse());
    _resetActionAfter(3000);
  }

  void _giveToy() {
    _actionResetTimer?.cancel();
    setState(() {
      _currentAction = DogAction.playing;
      _showStars = true;
      _actionMessage = '${petName} is playing! 🎾';
      petHappiness = (petHappiness + 20).clamp(0, 100);
      petEnergy = (petEnergy - 10).clamp(0, 100);
    });
    // Bounce rapidly 4 times
    _doBounceSeries(4);
    _resetActionAfter(4000);
  }

  void _doBounceSeries(int count) async {
    for (int i = 0; i < count; i++) {
      if (!mounted) return;
      await _bounceController.forward();
      await _bounceController.reverse();
    }
    if (mounted) setState(() => _showStars = false);
  }

  void _doZoomies() {
    _actionResetTimer?.cancel();
    setState(() {
      _currentAction = DogAction.zoomies;
      _actionMessage = '${petName} has the zoomies! 💨';
      petHappiness = (petHappiness + 15).clamp(0, 100);
      petEnergy = (petEnergy - 20).clamp(0, 100);
    });
    // Spin then shake rapidly
    _spinController.repeat();
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _spinController.stop();
      _shakeController.repeat(reverse: true);
      Timer(const Duration(milliseconds: 800), () {
        if (mounted) _shakeController.stop();
      });
    });
    _resetActionAfter(3000);
  }

  void _putToSleep() {
    _actionResetTimer?.cancel();
    setState(() {
      _currentAction = DogAction.sleeping;
      _showZzz = true;
      _actionMessage = '${petName} is napping... 😴';
      petEnergy = (petEnergy + 35).clamp(0, 100);
    });
    _floatController.repeat(reverse: true);
    _resetActionAfter(4000);
  }

  void _resetActionAfter(int ms) {
    _actionResetTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) {
        _floatController.stop();
        _floatController.reset();
        _spinController.stop();
        _spinController.reset();
        _shakeController.stop();
        _shakeController.reset();
        setState(() {
          _currentAction = DogAction.idle;
          _showHearts = false;
          _showZzz = false;
          _showStars = false;
          _actionMessage = '';
        });
      }
    });
  }

  Future<void> _feedPet(Map<String, dynamic> food) async {
    final cost = food['cost'] as int;
    if (userPoints < cost) {
      _showMessage('Need $cost points!', isError: true);
      return;
    }
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        _showMessage('Please log in', isError: true);
        return;
      }
      final newPoints = userPoints - cost;
      user['points'] = newPoints;
      final success = await AuthService.updateUser(user);
      if (success) {
        _actionResetTimer?.cancel();
        setState(() {
          userPoints = newPoints;
          petHunger = (petHunger + (food['hunger'] as int)).clamp(0, 100);
          petHappiness =
              (petHappiness + (food['happiness'] as int)).clamp(0, 100);
          petEnergy = (petEnergy + (food['energy'] as int)).clamp(0, 100);
          _showHearts = true;
          _currentAction = DogAction.eating;
          _actionMessage = '${petName} is eating! 😋';
        });
        _jumpController.forward().then((_) => _jumpController.reverse());
        _heartController.forward(from: 0);
        widget.onPointsChanged?.call();
        _showMessage('${food['name']} fed! -$cost pts');
        _resetActionAfter(2500);
      }
    } catch (e) {
      _showMessage('Error: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getStatColor(int value) {
    if (value > 70) return Colors.green;
    if (value > 40) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _tailWagController.dispose();
    _jumpController.dispose();
    _heartController.dispose();
    _spinController.dispose();
    _bounceController.dispose();
    _shakeController.dispose();
    _floatController.dispose();
    _degradationTimer?.cancel();
    _actionResetTimer?.cancel();
    super.dispose();
  }

  void _showPetWidget() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PetSheetContent(parent: this),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showPetWidget,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: CustomPaint(
                  size: Size(50, 50),
                  painter: PixelDogPainter(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Virtual Pet Dog',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Feed & play with $petName!',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Separate StatefulWidget for the bottom sheet so setState rebuilds it ──
class _PetSheetContent extends StatefulWidget {
  final _PixelPetWidgetState parent;
  const _PetSheetContent({required this.parent});

  @override
  State<_PetSheetContent> createState() => _PetSheetContentState();
}

class _PetSheetContentState extends State<_PetSheetContent> {
  _PixelPetWidgetState get p => widget.parent;

  @override
  void initState() {
    super.initState();
    // Listen to parent's animation controllers so we rebuild
    p._tailWagController.addListener(_rebuild);
    p._jumpController.addListener(_rebuild);
    p._heartController.addListener(_rebuild);
    p._spinController.addListener(_rebuild);
    p._bounceController.addListener(_rebuild);
    p._shakeController.addListener(_rebuild);
    p._floatController.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    p._tailWagController.removeListener(_rebuild);
    p._jumpController.removeListener(_rebuild);
    p._heartController.removeListener(_rebuild);
    p._spinController.removeListener(_rebuild);
    p._bounceController.removeListener(_rebuild);
    p._shakeController.removeListener(_rebuild);
    p._floatController.removeListener(_rebuild);
    super.dispose();
  }

  // Compute the current dog transform based on action
  Widget _buildAnimatedDog() {
    double dx = 0;
    double dy = 0;
    double rotation = 0;

    switch (p._currentAction) {
      case DogAction.jumping:
      case DogAction.eating:
      case DogAction.petted:
        dy = p._jumpAnimation.value;
        break;
      case DogAction.playing:
        dy = p._bounceAnimation.value;
        break;
      case DogAction.zoomies:
        dx = p._shakeAnimation.value;
        rotation = p._spinAnimation.value * 2 * 3.14159;
        break;
      case DogAction.sleeping:
        dy = p._floatAnimation.value;
        break;
      default:
        break;
    }

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: rotation,
        child: const SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(painter: PixelDogPainter()),
        ),
      ),
    );
  }

  Widget _buildOverlayEmoji() {
    if (p._showHearts) {
      return FadeTransition(
        opacity: p._heartAnimation,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('❤️', style: TextStyle(fontSize: 18)),
            Text('💕', style: TextStyle(fontSize: 22)),
            Text('❤️', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }
    if (p._showZzz) {
      return AnimatedBuilder(
        animation: p._floatAnimation,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, p._floatAnimation.value),
          child: const Text('💤', style: TextStyle(fontSize: 26)),
        ),
      );
    }
    if (p._showStars) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⭐', style: TextStyle(fontSize: 16)),
          Text('🎾', style: TextStyle(fontSize: 24)),
          Text('⭐', style: TextStyle(fontSize: 16)),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFE8F4F8),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🐕 ${p.petName}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${p.userPoints}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Pet display card ──────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Dog with overlay
                    SizedBox(
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          _buildAnimatedDog(),
                          // Floating emoji overlay (above dog)
                          Positioned(
                            top: 0,
                            child: _buildOverlayEmoji(),
                          ),
                        ],
                      ),
                    ),

                    // Action message
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: p._actionMessage.isNotEmpty
                          ? Container(
                              key: ValueKey(p._actionMessage),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF9C27B0)
                                        .withOpacity(0.3)),
                              ),
                              child: Text(
                                p._actionMessage,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7B1FA2)),
                              ),
                            )
                          : const SizedBox(key: ValueKey('empty'), height: 12),
                    ),

                    // Stat bars
                    _buildStatBar('Hunger', p.petHunger, '🍖'),
                    const SizedBox(height: 8),
                    _buildStatBar('Happy', p.petHappiness, '😊'),
                    const SizedBox(height: 8),
                    _buildStatBar('Energy', p.petEnergy, '⚡'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Action buttons ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Play with Rex',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildActionButton(
                                '🤚', 'Pet', 'Free', Colors.pink,
                                onTap: () {
                          p._petTheDog();
                          setState(() {});
                        })),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildActionButton(
                                '🎾', 'Toy', 'Free', Colors.orange,
                                onTap: () {
                          p._giveToy();
                          setState(() {});
                        })),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildActionButton(
                                '💨', 'Zoomies', 'Free', Colors.teal,
                                onTap: () {
                          p._doZoomies();
                          setState(() {});
                        })),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildActionButton(
                                '😴', 'Nap', 'Free', Colors.indigo,
                                onTap: () {
                          p._putToSleep();
                          setState(() {});
                        })),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Food shop ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Feed Rex',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0)),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: p.foodItems.length,
                      itemBuilder: (context, index) {
                        return _buildFoodCard(p.foodItems[index]);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
      String emoji, String label, String sublabel, Color color,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(sublabel,
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodCard(Map<String, dynamic> food) {
    final canAfford = p.userPoints >= food['cost'];

    return GestureDetector(
      onTap: canAfford
          ? () {
              p._feedPet(food);
              setState(() {});
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: canAfford
                ? const Color(0xFF1565C0).withOpacity(0.3)
                : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(food['emoji'],
                style: TextStyle(
                    fontSize: 38,
                    color: canAfford ? null : Colors.grey[400])),
            const SizedBox(height: 6),
            Text(food['name'],
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: canAfford ? Colors.black87 : Colors.grey[400])),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                if (food['hunger'] > 0)
                  _buildMiniChip('🍖+${food['hunger']}', canAfford),
                if (food['happiness'] > 0)
                  _buildMiniChip('😊+${food['happiness']}', canAfford),
                if (food['energy'] > 0)
                  _buildMiniChip('⚡+${food['energy']}', canAfford),
              ],
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: canAfford ? const Color(0xFFFFD700) : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars,
                      size: 14,
                      color: canAfford ? Colors.white : Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('${food['cost']}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color:
                              canAfford ? Colors.white : Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(String text, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFF1565C0).withOpacity(0.1)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9,
              color: enabled ? const Color(0xFF1565C0) : Colors.grey[500],
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatBar(String label, int value, String emoji) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  Text('$value',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: p._getStatColor(value))),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                      p._getStatColor(value)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Pixel art dog painter (unchanged visual) ─────────────────────────────────
class PixelDogPainter extends CustomPainter {
  const PixelDogPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pixelSize = size.width / 16;

    final bodyPaint = Paint()
      ..color = const Color(0xFFD2691E)
      ..style = PaintingStyle.fill;
    final darkBodyPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;
    final lightBodyPaint = Paint()
      ..color = const Color(0xFFF4A460)
      ..style = PaintingStyle.fill;
    final nosePaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;
    final eyePaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;
    final eyeShine = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    final tonguePaint = Paint()
      ..color = const Color(0xFFFF69B4)
      ..style = PaintingStyle.fill;
    final bellyPaint = Paint()
      ..color = const Color(0xFFFFE4B5)
      ..style = PaintingStyle.fill;

    void drawPixel(int x, int y, Paint paint) {
      canvas.drawRect(
        Rect.fromLTWH(x * pixelSize, y * pixelSize, pixelSize, pixelSize),
        paint,
      );
    }

    // Ears
    drawPixel(3, 2, darkBodyPaint);
    drawPixel(2, 3, darkBodyPaint);
    drawPixel(2, 4, darkBodyPaint);
    drawPixel(3, 5, darkBodyPaint);
    drawPixel(12, 2, darkBodyPaint);
    drawPixel(13, 3, darkBodyPaint);
    drawPixel(13, 4, darkBodyPaint);
    drawPixel(12, 5, darkBodyPaint);
    drawPixel(3, 3, bodyPaint);
    drawPixel(12, 3, bodyPaint);

    // Head outline
    for (int x = 4; x <= 11; x++) drawPixel(x, 1, darkBodyPaint);

    // Top of head
    for (int x = 4; x <= 11; x++) {
      drawPixel(x, 2, (x == 7 || x == 8) ? lightBodyPaint : bodyPaint);
    }

    // Face rows 1-3
    for (int y = 3; y <= 5; y++) {
      for (int x = 4; x <= 11; x++) {
        drawPixel(x, y, bodyPaint);
      }
    }

    // Eyes
    drawPixel(5, 4, eyePaint);
    drawPixel(10, 4, eyePaint);
    drawPixel(5, 3, eyeShine);
    drawPixel(10, 3, eyeShine);

    // Snout
    for (int x = 5; x <= 10; x++) drawPixel(x, 5, lightBodyPaint);
    for (int x = 5; x <= 10; x++) {
      drawPixel(x, 6, (x == 7 || x == 8) ? nosePaint : lightBodyPaint);
    }
    drawPixel(6, 7, lightBodyPaint);
    drawPixel(7, 7, tonguePaint);
    drawPixel(8, 7, tonguePaint);
    drawPixel(9, 7, lightBodyPaint);

    // Body
    for (int x = 3; x <= 12; x++) {
      if (x != 7) drawPixel(x, 9, bodyPaint);
    }
    for (int y = 10; y <= 11; y++) {
      drawPixel(3, y, bodyPaint);
      drawPixel(4, y, bodyPaint);
      for (int x = 5; x <= 9; x++) drawPixel(x, y, bellyPaint);
      drawPixel(10, y, bodyPaint);
      drawPixel(11, y, bodyPaint);
      drawPixel(12, y, bodyPaint);
    }

    // Legs
    for (int y = 12; y <= 13; y++) {
      drawPixel(4, y, bodyPaint);
      drawPixel(5, y, bodyPaint);
      drawPixel(9, y, bodyPaint);
      drawPixel(10, y, bodyPaint);
      drawPixel(3, y, bodyPaint);
      drawPixel(11, y, bodyPaint);
      drawPixel(12, y, bodyPaint);
    }

    // Paws
    for (int x in [3, 4, 5, 9, 10, 11, 12]) {
      drawPixel(x, 14, darkBodyPaint);
    }

    // Tail
    drawPixel(13, 10, darkBodyPaint);
    drawPixel(14, 9, darkBodyPaint);
    drawPixel(14, 8, darkBodyPaint);
    drawPixel(15, 7, darkBodyPaint);
    drawPixel(15, 6, bodyPaint);
    drawPixel(15, 5, lightBodyPaint);
  }

  @override
  bool shouldRepaint(PixelDogPainter oldDelegate) => false;
}