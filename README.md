# Too-Good-To-MISS

## 📖 Overview

**Too Good To MISS** is a comprehensive mobile application built with Flutter that connects users with local startups and small businesses in their area. The app provides an intuitive platform for discovering, reviewing, and bookmarking businesses while offering special deals and promotions to users.

This project demonstrates advanced mobile development skills including interactive maps integration, persistent data storage, user authentication, and a clean object-oriented architecture.

---

## ✨ Key Features

### 🗺️ **Interactive Maps View**
- Browse all local startups on an interactive Google Maps interface
- Color-coded markers based on business categories (Food, Retail, Technology, Services)
- Real-time filtering and sorting capabilities
- Tap markers to view detailed business information

### 🔍 **Advanced Filtering & Sorting**
- **Filter by Category**: Food, Retail, Technology, Services, or view All
- **Sort Options**: 
  - By Rating (highest to lowest)
  - By Name (alphabetical)
  - By Review Count (most reviewed first)

### ⭐ **Review System**
- Users can leave ratings (1-5 stars) and detailed comments
- Bot verification system to prevent spam reviews
- Review timestamps with relative time display
- Average rating calculation

### 💝 **Favorites/Bookmarking**
- Save favorite businesses for quick access
- Visual favorite indicators
- Track favorite count in user profile

### 🎁 **Special Deals & Promotions**
- One-tap code copying to clipboard
- Beautiful gradient card design for deals

### 👤 **User Authentication**
- Secure sign up and login system
- Session persistence
- Edit profile information
- Personalized experience

### ⚙️ **Comprehensive Settings**
- **Edit Profile**: Update username and email
- **Notifications**: Customize notification preferences
- **Privacy & Security**: Control visibility and data settings
- **Help & Support**: FAQ, feedback, and bug reporting
- **About**: App information and legal documents

### 💼 **Business Dashboard** (For Business Users)
- Register new businesses with location picker
- Manage business information

### 📊 **User Profile**
- Points system for engagement
- Track reviews posted
- View places visited
- Achievements and badges
- Member since information

---

## 🛠️ Tech Stack

### **Framework & Language**
- **Flutter 3.0+** - Cross-platform mobile framework
- **Dart 3.0+** - Programming language with strong OOP support

### **Maps & Location**
- **google_maps_flutter (^2.5.0)** - Google Maps integration
- **geocoding (^2.1.1)** - Address conversion and location services
- **Haversine Formula** - Distance calculations between coordinates

### **Data Storage & Persistence**
- **shared_preferences (^2.2.2)** - Local key-value storage for user data
- **JSON** - Data serialization and storage
  - `startups.json` - Business database
  - `reviews.json` - User reviews storage

### **UI/UX**
- **Material Design 3** - Modern UI components
- **Custom Widgets** - Gradient backgrounds, animations, cards
- **Animations** - Fade transitions, typing indicators, smooth scrolling

### **External Integration**
- **url_launcher (^6.2.1)** - Email, phone, and web URL handling
- **Google Maps API** - Maps SDK for Android and iOS

### **Architecture & Design Patterns**
- **Object-Oriented Programming (OOP)** - Clean class structure
- **Service Layer Pattern** - Separation of business logic
- **Repository Pattern** - Data access abstraction
- **Factory Pattern** - JSON serialization/deserialization
- **Singleton Pattern** - Service management

## 🎨 Design Highlights

### **Color Scheme**
- Primary: `#1565C0` (Blue)
- Background: `#E8F4F8` (Light Blue)
- Accent: Purple gradient
- Success: Green
- Warning: Orange
- Error: Red

### **Typography**
- Headers: Bold, 20-32px
- Body: Regular, 14-16px
- Captions: Light, 12-13px

### **UI Components**
- Rounded corners throughout (12-20px radius)
- Consistent shadows for depth
- Gradient backgrounds for premium feel
- Smooth animations and transitions


## 📊 Performance Optimizations

- Lazy loading of data
- Efficient JSON parsing
- Marker clustering for large datasets
- Asset optimization
- Asynchronous operations

## 👥 Authors

- **Hasini** - *Initial work* - [hasini2k8@gmail.com](mailto:hasini2k8@gmail.com)

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Google Maps Platform for location services
- Material Design for UI inspiration
- Open source community for packages and support

---

## 📧 Contact

**Email**: hasini2k8@gmail.com  
**Location**: Markham, Ontario, Canada

---

## 🔮 Future Enhancements

- [ ] Enhancing the Business end dashboard to have better features
- [ ] Multi-language support
- [ ] Implement it in real time Android and IOS phones
- [ ] Offline mode support

---


was built as a demonstration of advanced Flutter development skills including Google Maps integration, OOP architecture, data persistence, and clean UI/UX design.*
