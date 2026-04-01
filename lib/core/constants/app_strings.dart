class AppStrings {
  AppStrings._();

  static const String appName = 'Nagar Sewa';
  static const String tagline = 'Small reports. Big change.';

  // Auth
  static const String loginNow = 'Login Now';
  static const String registerNow = 'Register Now';
  static const String signIn = 'Sign In';
  static const String signUp = 'Sign Up';
  static const String forgotPassword = 'Forgot password?';
  static const String haveAccount = 'Have an account? Login now';
  static const String noAccount = 'Don\'t have an account? Register';
  static const String mobileVerification = 'Mobile Verification';
  static const String sendOtp = 'Send OTP';
  static const String verifyOtp = 'Verify OTP';
  static const String changeDetails = 'Change details';

  // Form labels
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm password';
  static const String fullName = 'Full name';
  static const String phoneNumber = 'Phone number';
  static const String enterEmail = 'Enter your email';
  static const String enterPassword = 'Enter password';
  static const String enterName = 'Enter your full name';
  static const String enterPhone = 'Enter phone number';
  static const String enterOtp = 'Enter OTP';

  // Dashboard
  static const String overview = 'Overview';
  static const String resolved = 'Resolved';
  static const String urgent = 'Urgent';
  static const String reported = 'Reported';
  static const String community = 'Community';
  static const String resolvedIssues = 'Resolved Issues';
  static const String unresolvedIssues = 'Unresolved Issues';
  static const String myIssues = 'My Issues';
  static const String nearbyIssues = 'Nearby Issues';
  static const String recentActivity = 'Recent Activity';
  static const String viewAll = 'View All';

  // Report
  static const String reportIssue = 'Report Issue';
  static const String uploadEvidence = 'Upload Evidence';
  static const String clickPhoto = 'Click Photo';
  static const String recordVideo = 'Record Video';
  static const String locationReadOnly = 'Location (Read Only)';
  static const String autoFetch = 'Auto Fetch';
  static const String description = 'Description';
  static const String writeBriefly = 'Write briefly about the Issue';
  static const String liveMap = 'Live Map';
  static const String viewMap = 'View Map';
  static const String submit = 'Submit';
  static const String draft = 'Draft';

  // Navigation
  static const String dashboard = 'Dashboard';
  static const String history = 'History';
  static const String map = 'Map';
  static const String chat = 'Chat';

  // Issue statuses (display names)
  static const Map<String, String> statusLabels = {
    'submitted': 'Submitted',
    'assigned': 'Assigned',
    'acknowledged': 'Acknowledged',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
    'citizen_confirmed': 'Confirmed',
    'closed': 'Closed',
    'rejected': 'Rejected',
  };

  // Issue categories (display names)
  static const Map<String, String> categoryLabels = {
    'pothole': 'Pothole',
    'garbage_overflow': 'Garbage Overflow',
    'broken_streetlight': 'Broken Streetlight',
    'sewage_leak': 'Sewage Leak',
    'encroachment': 'Encroachment',
    'damaged_road_divider': 'Damaged Road Divider',
    'broken_footpath': 'Broken Footpath',
    'open_manhole': 'Open Manhole',
    'waterlogging': 'Waterlogging',
    'construction_debris': 'Construction Debris',
    'other': 'Other',
  };

  static const String online = 'Online';
  static const String offline = 'Offline';
  static const String notifications = 'Notifications';
  static const String profile = 'Profile';
  static const String settings = 'Settings';
  static const String logout = 'Logout';
}
