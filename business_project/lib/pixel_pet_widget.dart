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

class _PixelPetWidgetState extends State<PixelPetWidget> with TickerProviderStateMixin {
  // User stats
  int userPoints = 0;
  
  // Pet stats
  int petHunger = 50;
  int petHappiness = 50;
  int petEnergy = 50;
  String petName = 'Rex';
  
  // Accessories (owned items)
  Set<String> ownedAccessories = {};
  String? equippedHat;
  String? equippedCollar;
  String? equippedToy;
  
  // Animation controllers
  late AnimationController _tailWagController;
  late AnimationController _jumpController;
  late AnimationController _heartController;
  late Animation<double> _tailWagAnimation;
  late Animation<double> _jumpAnimation;
  late Animation<double> _heartAnimation;
  
  bool _showHearts = false;
  bool _isLoading = true;
  Timer? _degradationTimer;
  
  // Current tab (0: Food, 1: Accessories)
  int _currentTab = 0;
  
  // Food items
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
  
  // Accessories
  final List<Map<String, dynamic>> accessories = [
    {
      'id': 'hat_party',
      'name': 'Party Hat',
      'emoji': '🎩',
      'type': 'hat',
      'cost': 50,
    },
    {
      'id': 'hat_crown',
      'name': 'Crown',
      'emoji': '👑',
      'type': 'hat',
      'cost': 100,
    },
    {
      'id': 'hat_bow',
      'name': 'Bow',
      'emoji': '🎀',
      'type': 'hat',
      'cost': 40,
    },
    {
      'id': 'collar_red',
      'name': 'Red Collar',
      'emoji': '🔴',
      'type': 'collar',
      'cost': 30,
    },
    {
      'id': 'collar_gold',
      'name': 'Gold Collar',
      'emoji': '🟡',
      'type': 'collar',
      'cost': 75,
    },
    {
      'id': 'collar_diamond',
      'name': 'Diamond Collar',
      'emoji': '💎',
      'type': 'collar',
      'cost': 150,
    },
    {
      'id': 'toy_ball',
      'name': 'Ball',
      'emoji': '⚽',
      'type': 'toy',
      'cost': 25,
    },
    {
      'id': 'toy_frisbee',
      'name': 'Frisbee',
      'emoji': '🥏',
      'type': 'toy',
      'cost': 35,
    },
    {
      'id': 'toy_bone',
      'name': 'Toy Bone',
      'emoji': '🦴',
      'type': 'toy',
      'cost': 20,
    },
  ];

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _tailWagController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _tailWagAnimation = Tween<double>(begin: 0, end: 0.1).animate(
      CurvedAnimation(parent: _tailWagController, curve: Curves.easeInOut),
    );
    
    _jumpAnimation = Tween<double>(begin: 0, end: -30).animate(
      CurvedAnimation(parent: _jumpController, curve: Curves.easeOut),
    );
    
    _heartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeOut),
    );
    
    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHearts = false);
        _heartController.reset();
      }
    });
    
    // Start tail wag loop
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
      print('Error loading game data: $e');
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

  Future<void> _feedPet(Map<String, dynamic> food) async {
    final cost = food['cost'] as int;
    
    if (userPoints < cost) {
      _showMessage('Need ${cost} points!', isError: true);
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
        setState(() {
          userPoints = newPoints;
          petHunger = (petHunger + (food['hunger'] as int)).clamp(0, 100);
          petHappiness = (petHappiness + (food['happiness'] as int)).clamp(0, 100);
          petEnergy = (petEnergy + (food['energy'] as int)).clamp(0, 100);
          _showHearts = true;
        });

        _jumpController.forward().then((_) => _jumpController.reverse());
        _heartController.forward();
        widget.onPointsChanged?.call();
        
        _showMessage('${food['name']} fed! -$cost pts', isError: false);
      }
    } catch (e) {
      _showMessage('Error: $e', isError: true);
    }
  }

  Future<void> _buyAccessory(Map<String, dynamic> accessory) async {
    final cost = accessory['cost'] as int;
    final id = accessory['id'] as String;
    
    if (ownedAccessories.contains(id)) {
      _equipAccessory(accessory);
      return;
    }
    
    if (userPoints < cost) {
      _showMessage('Need ${cost} points!', isError: true);
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
        setState(() {
          userPoints = newPoints;
          ownedAccessories.add(id);
          petHappiness = (petHappiness + 15).clamp(0, 100);
        });

        _equipAccessory(accessory);
        _jumpController.forward().then((_) => _jumpController.reverse());
        widget.onPointsChanged?.call();
        
        _showMessage('${accessory['name']} bought! -$cost pts', isError: false);
      }
    } catch (e) {
      _showMessage('Error: $e', isError: true);
    }
  }

  void _equipAccessory(Map<String, dynamic> accessory) {
    setState(() {
      final type = accessory['type'] as String;
      final id = accessory['id'] as String;
      
      switch (type) {
        case 'hat':
          equippedHat = equippedHat == id ? null : id;
          break;
        case 'collar':
          equippedCollar = equippedCollar == id ? null : id;
          break;
        case 'toy':
          equippedToy = equippedToy == id ? null : id;
          break;
      }
    });
  }

  void _showMessage(String message, {required bool isError}) {
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
    _degradationTimer?.cancel();
    super.dispose();
  }

  void _showPetWidget() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPetBottomSheet(),
    );
  }

  Widget _buildPetBottomSheet() {
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
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🐕 $petName',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '$userPoints',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Pet display
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
                    // Pet character with accessories
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Hearts animation
                        if (_showHearts)
                          Positioned(
                            top: -40,
                            child: FadeTransition(
                              opacity: _heartAnimation,
                              child: Row(
                                children: List.generate(
                                  3,
                                  (i) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: Text('❤️', style: TextStyle(fontSize: 16 + i * 4.0)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        
                        // Pet with jump animation
                        AnimatedBuilder(
                          animation: _jumpAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _jumpAnimation.value),
                              child: _buildPixelDog(),
                            );
                          },
                        ),
                        
                        // Equipped hat
                        if (equippedHat != null)
                          Positioned(
                            top: -15,
                            child: Text(
                              accessories.firstWhere((a) => a['id'] == equippedHat)['emoji'],
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        
                        // Equipped toy
                        if (equippedToy != null)
                          Positioned(
                            right: -20,
                            bottom: 20,
                            child: Text(
                              accessories.firstWhere((a) => a['id'] == equippedToy)['emoji'],
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Stats
                    _buildStatBar('Hunger', petHunger, '🍖'),
                    const SizedBox(height: 8),
                    _buildStatBar('Happy', petHappiness, '😊'),
                    const SizedBox(height: 8),
                    _buildStatBar('Energy', petEnergy, '⚡'),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton('Food', 0),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTabButton('Accessories', 1),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Content
              Expanded(
                child: _currentTab == 0
                    ? _buildFoodShop(scrollController)
                    : _buildAccessoriesShop(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPixelDog() {
    return Container(
      width: 140,
      height: 140,
      child: CustomPaint(
        painter: PixelDogPainter(
          collarColor: equippedCollar != null
              ? _getCollarColor(equippedCollar!)
              : null,
        ),
      ),
    );
  }

  Color _getCollarColor(String collarId) {
    if (collarId.contains('red')) return Colors.red;
    if (collarId.contains('gold')) return Colors.amber;
    if (collarId.contains('diamond')) return Colors.cyan;
    return Colors.brown;
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodShop(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: foodItems.length,
          itemBuilder: (context, index) {
            return _buildFoodCard(foodItems[index]);
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAccessoriesShop(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: accessories.length,
          itemBuilder: (context, index) {
            return _buildAccessoryCard(accessories[index]);
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFoodCard(Map<String, dynamic> food) {
    final canAfford = userPoints >= food['cost'];
    
    return GestureDetector(
      onTap: canAfford ? () => _feedPet(food) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: canAfford ? const Color(0xFF1565C0).withOpacity(0.3) : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              food['emoji'],
              style: TextStyle(
                fontSize: 40,
                color: canAfford ? null : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              food['name'],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: canAfford ? Colors.black87 : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: canAfford ? const Color(0xFFFFD700) : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars, size: 14, color: canAfford ? Colors.white : Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${food['cost']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: canAfford ? Colors.white : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessoryCard(Map<String, dynamic> accessory) {
    final id = accessory['id'] as String;
    final isOwned = ownedAccessories.contains(id);
    final canAfford = userPoints >= accessory['cost'] || isOwned;
    final type = accessory['type'] as String;
    final isEquipped = (type == 'hat' && equippedHat == id) ||
                       (type == 'collar' && equippedCollar == id) ||
                       (type == 'toy' && equippedToy == id);
    
    return GestureDetector(
      onTap: canAfford ? () => _buyAccessory(accessory) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEquipped
                ? Colors.green
                : (canAfford ? const Color(0xFF9C27B0).withOpacity(0.3) : Colors.grey[300]!),
            width: isEquipped ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Text(
                  accessory['emoji'],
                  style: TextStyle(
                    fontSize: 48,
                    color: canAfford ? null : Colors.grey[400],
                  ),
                ),
                if (isOwned && isEquipped)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              accessory['name'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: canAfford ? Colors.black87 : Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (isOwned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isEquipped ? Colors.green : const Color(0xFF9C27B0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isEquipped ? 'Equipped' : 'Equip',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: canAfford ? const Color(0xFFFFD700) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, size: 14, color: canAfford ? Colors.white : Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${accessory['cost']}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: canAfford ? Colors.white : Colors.grey[500],
                      ),
                    ),
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
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: enabled ? const Color(0xFF1565C0) : Colors.grey[500],
          fontWeight: FontWeight.w600,
        ),
      ),
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
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatColor(value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(_getStatColor(value)),
                ),
              ),
            ],
          ),
        ),
      ],
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
            colors: [
              Color(0xFF9C27B0),
              Color(0xFF7B1FA2),
            ],
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
            // Mini pixel dog preview
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(50, 50),
                  painter: PixelDogPainter(
                    collarColor: equippedCollar != null
                        ? _getCollarColor(equippedCollar!)
                        : null,
                  ),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Feed & dress up $petName!',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for pixel art dog
class PixelDogPainter extends CustomPainter {
  final Color? collarColor;
  
  PixelDogPainter({this.collarColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final pixelSize = size.width / 16;
    
    // Color palette
    final bodyPaint = Paint()
      ..color = const Color(0xFFD2691E) // Chocolate brown
      ..style = PaintingStyle.fill;
    
    final darkBodyPaint = Paint()
      ..color = const Color(0xFF8B4513) // Saddle brown
      ..style = PaintingStyle.fill;
    
    final lightBodyPaint = Paint()
      ..color = const Color(0xFFF4A460) // Sandy brown (highlights)
      ..style = PaintingStyle.fill;
    
    final nosePaint = Paint()
      ..color = const Color(0xFF000000) // Black
      ..style = PaintingStyle.fill;
    
    final eyePaint = Paint()
      ..color = const Color(0xFF000000) // Black
      ..style = PaintingStyle.fill;
    
    final eyeShine = Paint()
      ..color = const Color(0xFFFFFFFF) // White
      ..style = PaintingStyle.fill;
    
    final tonguePaint = Paint()
      ..color = const Color(0xFFFF69B4) // Pink
      ..style = PaintingStyle.fill;
    
    final collarPaint = Paint()
      ..color = collarColor ?? const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;
    
    final collarTagPaint = Paint()
      ..color = const Color(0xFFFFD700) // Gold tag
      ..style = PaintingStyle.fill;
    
    final bellyPaint = Paint()
      ..color = const Color(0xFFFFE4B5) // Moccasin (belly)
      ..style = PaintingStyle.fill;
    
    // Helper to draw pixel
    void drawPixel(int x, int y, Paint paint) {
      canvas.drawRect(
        Rect.fromLTWH(x * pixelSize, y * pixelSize, pixelSize, pixelSize),
        paint,
      );
    }
    
    // ==== HEAD ====
    
    // Ears (floppy)
    drawPixel(3, 2, darkBodyPaint);
    drawPixel(2, 3, darkBodyPaint);
    drawPixel(2, 4, darkBodyPaint);
    drawPixel(3, 5, darkBodyPaint);
    
    drawPixel(12, 2, darkBodyPaint);
    drawPixel(13, 3, darkBodyPaint);
    drawPixel(13, 4, darkBodyPaint);
    drawPixel(12, 5, darkBodyPaint);
    
    // Ear highlights
    drawPixel(3, 3, bodyPaint);
    drawPixel(12, 3, bodyPaint);
    
    // Head outline
    drawPixel(4, 1, darkBodyPaint);
    drawPixel(5, 1, darkBodyPaint);
    drawPixel(6, 1, darkBodyPaint);
    drawPixel(7, 1, darkBodyPaint);
    drawPixel(8, 1, darkBodyPaint);
    drawPixel(9, 1, darkBodyPaint);
    drawPixel(10, 1, darkBodyPaint);
    drawPixel(11, 1, darkBodyPaint);
    
    // Top of head
    drawPixel(4, 2, bodyPaint);
    drawPixel(5, 2, bodyPaint);
    drawPixel(6, 2, bodyPaint);
    drawPixel(7, 2, lightBodyPaint); // Highlight
    drawPixel(8, 2, lightBodyPaint);
    drawPixel(9, 2, bodyPaint);
    drawPixel(10, 2, bodyPaint);
    drawPixel(11, 2, bodyPaint);
    
    // Face row 1
    drawPixel(4, 3, bodyPaint);
    drawPixel(5, 3, bodyPaint);
    drawPixel(6, 3, bodyPaint);
    drawPixel(7, 3, bodyPaint);
    drawPixel(8, 3, bodyPaint);
    drawPixel(9, 3, bodyPaint);
    drawPixel(10, 3, bodyPaint);
    drawPixel(11, 3, bodyPaint);
    
    // Eyes row
    drawPixel(4, 4, bodyPaint);
    drawPixel(5, 4, eyePaint); // Left eye
    drawPixel(6, 4, bodyPaint);
    drawPixel(7, 4, bodyPaint);
    drawPixel(8, 4, bodyPaint);
    drawPixel(9, 4, bodyPaint);
    drawPixel(10, 4, eyePaint); // Right eye
    drawPixel(11, 4, bodyPaint);
    
    // Eye shine
    drawPixel(5, 3, eyeShine);
    drawPixel(10, 3, eyeShine);
    
    // Snout row 1
    drawPixel(4, 5, bodyPaint);
    drawPixel(5, 5, lightBodyPaint);
    drawPixel(6, 5, lightBodyPaint);
    drawPixel(7, 5, lightBodyPaint);
    drawPixel(8, 5, lightBodyPaint);
    drawPixel(9, 5, lightBodyPaint);
    drawPixel(10, 5, lightBodyPaint);
    drawPixel(11, 5, bodyPaint);
    
    // Snout row 2 with nose
    drawPixel(5, 6, lightBodyPaint);
    drawPixel(6, 6, lightBodyPaint);
    drawPixel(7, 6, nosePaint); // Nose
    drawPixel(8, 6, nosePaint);
    drawPixel(9, 6, lightBodyPaint);
    drawPixel(10, 6, lightBodyPaint);
    
    // Mouth/tongue
    drawPixel(6, 7, lightBodyPaint);
    drawPixel(7, 7, tonguePaint);
    drawPixel(8, 7, tonguePaint);
    drawPixel(9, 7, lightBodyPaint);
    
    // ==== COLLAR ====
    if (collarColor != null) {
      drawPixel(4, 8, collarPaint);
      drawPixel(5, 8, collarPaint);
      drawPixel(6, 8, collarPaint);
      drawPixel(7, 8, collarPaint);
      drawPixel(8, 8, collarPaint);
      drawPixel(9, 8, collarPaint);
      drawPixel(10, 8, collarPaint);
      drawPixel(11, 8, collarPaint);
      
      // Collar tag
      drawPixel(7, 9, collarTagPaint);
    }
    
    // ==== BODY ====
    
    // Body row 1
    drawPixel(3, 9, bodyPaint);
    drawPixel(4, 9, bodyPaint);
    drawPixel(5, 9, bodyPaint);
    drawPixel(6, 9, bodyPaint);
    drawPixel(8, 9, bodyPaint);
    drawPixel(9, 9, bodyPaint);
    drawPixel(10, 9, bodyPaint);
    drawPixel(11, 9, bodyPaint);
    drawPixel(12, 9, bodyPaint);
    
    // Body row 2 with belly
    drawPixel(3, 10, bodyPaint);
    drawPixel(4, 10, bodyPaint);
    drawPixel(5, 10, bellyPaint);
    drawPixel(6, 10, bellyPaint);
    drawPixel(7, 10, bellyPaint);
    drawPixel(8, 10, bellyPaint);
    drawPixel(9, 10, bellyPaint);
    drawPixel(10, 10, bodyPaint);
    drawPixel(11, 10, bodyPaint);
    drawPixel(12, 10, bodyPaint);
    
    // Body row 3
    drawPixel(3, 11, bodyPaint);
    drawPixel(4, 11, bodyPaint);
    drawPixel(5, 11, bellyPaint);
    drawPixel(6, 11, bellyPaint);
    drawPixel(7, 11, bellyPaint);
    drawPixel(8, 11, bellyPaint);
    drawPixel(9, 11, bellyPaint);
    drawPixel(10, 11, bodyPaint);
    drawPixel(11, 11, bodyPaint);
    drawPixel(12, 11, bodyPaint);
    
    // ==== LEGS ====
    
    // Front legs
    drawPixel(4, 12, bodyPaint);
    drawPixel(5, 12, bodyPaint);
    drawPixel(9, 12, bodyPaint);
    drawPixel(10, 12, bodyPaint);
    
    drawPixel(4, 13, bodyPaint);
    drawPixel(5, 13, bodyPaint);
    drawPixel(9, 13, bodyPaint);
    drawPixel(10, 13, bodyPaint);
    
    // Paws
    drawPixel(4, 14, darkBodyPaint);
    drawPixel(5, 14, darkBodyPaint);
    drawPixel(9, 14, darkBodyPaint);
    drawPixel(10, 14, darkBodyPaint);
    
    // Back legs
    drawPixel(3, 12, bodyPaint);
    drawPixel(11, 12, bodyPaint);
    drawPixel(12, 12, bodyPaint);
    
    drawPixel(3, 13, bodyPaint);
    drawPixel(11, 13, bodyPaint);
    drawPixel(12, 13, bodyPaint);
    
    drawPixel(3, 14, darkBodyPaint);
    drawPixel(11, 14, darkBodyPaint);
    drawPixel(12, 14, darkBodyPaint);
    
    // ==== TAIL ====
    drawPixel(13, 10, darkBodyPaint);
    drawPixel(14, 9, darkBodyPaint);
    drawPixel(14, 8, darkBodyPaint);
    drawPixel(15, 7, darkBodyPaint);
    drawPixel(15, 6, bodyPaint);
    drawPixel(15, 5, lightBodyPaint); // Tail tip
  }
  
  @override
  bool shouldRepaint(PixelDogPainter oldDelegate) {
    return oldDelegate.collarColor != collarColor;
  }
}