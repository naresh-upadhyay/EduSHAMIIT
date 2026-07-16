import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/config/app_config.dart';

class SharedUserGuidesScreen extends StatefulWidget {
  final String? systemName;
  final String? systemLogo;
  final String? illustrationUrl;
  final String? videoIllustrationUrl;
  final String? initialCategory;
  final String? initialArticleId;

  const SharedUserGuidesScreen({
    Key? key,
    this.systemName,
    this.systemLogo,
    this.illustrationUrl,
    this.videoIllustrationUrl,
    this.initialCategory,
    this.initialArticleId,
  }) : super(key: key);

  @override
  State<SharedUserGuidesScreen> createState() => _SharedUserGuidesScreenState();
}

class _SharedUserGuidesScreenState extends State<SharedUserGuidesScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedArticleId;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _articles = [
    {
      'id': 'welcome',
      'category': 'Getting Started',
      'title': 'Welcome to School ERP',
      'readTime': '3 min read',
      'icon': Icons.emoji_emotions_outlined,
      'summary': 'Overview of School ERP and its key benefits.',
      'content': '''
# Welcome to School ERP

We are thrilled to welcome you to School ERP, the next-generation, all-in-one school administration and learning management platform. 

This guide will introduce you to the core benefits of our platform and give you a brief tour of the key areas of the dashboard.

---

## 🌟 Key Benefits of School ERP

1. **Integrated Operations**: Manage academic admissions, scheduling, examinations, fee collection, staff payroll, and student transport in a single, unified database.
2. **Real-time Live Classes**: Conduct interactive virtual classrooms with live whiteboard overlays, audio/video recording, and live discussion comments.
3. **Automated Online Exams**: Assign digital tests, enable camera and microphone proctoring to prevent cheating, and publish instant graded reports.
4. **Smart AI Insights**: Track performance averages, student activity milestones, and flag low-participation risks automatically.

---

## 🧭 Dashboard Quick Tour

On your left sidebar, you will find direct navigation paths to modules based on your role:
- **Academics**: Access courses, timetable scheduler, and syllabus chapters.
- **Examinations**: Manage question banks, exam papers, and grades.
- **Finance**: Generate student fee receipts and monitor transaction logs.
- **Infrastructure**: Monitor live servers, service uptime, and database storage metrics.
- **Support**: Submit and track help tickets with our customer care experts.
'''
    },
    {
      'id': 'create-account',
      'category': 'Getting Started',
      'title': 'Create Your Account',
      'readTime': '4 min read',
      'icon': Icons.person_add_outlined,
      'summary': 'Learn how to sign up and set up your organization.',
      'content': '''
# Setting Up Your Institution Account

Onboarding your school to our ERP takes only a few minutes. Follow this detailed step-by-step setup guide.

---

## 📝 Step-by-Step Onboarding Steps

### Step 1: Provide Administrator Profile Info
Fill in your basic personal credentials:
- **Full Name**: Your official name (used as the primary system administrator).
- **Email Address**: Your primary admin email (will be used for login).
- **Password**: Create a secure password (minimum 6 characters).

### Step 2: Input School Details
Provide the school's general directory information:
- **School Name**: The official name of your institution.
- **Address**: Full physical campus address.
- **Affiliation Board**: Dropdown choice (CBSE, ICSE, State Board, IB, or Other).
- **School Phone**: The main administrative phone line.

### Step 3: Choose Plan & Payment
Select a subscription tier that matches your school's student volume:
- **Basic Plan**: Ideal for small schools (up to 500 students).
- **Premium Plan**: Recommended (includes advanced analytics and IoT controller support).
- **Enterprise Plan**: Custom hosting and unlimited capacity.
- Select your payment cycle (Monthly or Yearly to save 10%) and complete the payment simulation (UPI, Cards, or NetBanking).

### Step 4: Awaiting Superadmin Activation
Once submitted, your school starts in New status. Our system superadmins will verify the billing details and activate your instance within 24 hours. You will receive an email confirmation once activated, and your admin login credentials will start working immediately.
'''
    },
    {
      'id': 'dashboard-overview',
      'category': 'Getting Started',
      'title': 'Dashboard Overview',
      'readTime': '5 min read',
      'icon': Icons.dashboard_outlined,
      'summary': 'Understand the dashboard and its key components.',
      'content': '''
# Navigating the Dashboard Interface

The School ERP dashboard is designed to present relevant widgets, shortcuts, and key metrics based on your role.

---

## 🎛️ Primary Layout Sections

1. **Main Header**: Offers search functionality, notification center access, and profile settings.
2. **Module Sidebar**: Expandable vertical menu on the left providing access to academic, administrative, and system modules.
3. **Interactive Widget Grid**:
   - **Quick Actions**: Icons for adding students, creating announcements, or recording attendance.
   - **Analytical Gauges**: Graphs showing attendance percentages, fee collection progress, and library catalog activity.
   - **AI Recommendations**: Summary cards showing system health recommendations and active alerts.
4. **Active System Log**: Displays recent administrative updates, failed login logs, and module status logs.
'''
    },
    {
      'id': 'basic-settings',
      'category': 'Getting Started',
      'title': 'Basic Settings',
      'readTime': '6 min read',
      'icon': Icons.settings_outlined,
      'summary': 'Configure basic settings for your institution.',
      'content': '''
# Configuring School Profile & Settings

After your school is activated, the first step is to configure your general settings to match your institution.

---

## ⚙️ How to Access General Settings
1. Log in with your registered administrator account.
2. Navigate to Admin Settings > System Configuration on the left menu.

---

## 🛠️ Key Settings Categories

### 1. General Profile
- **Institution Name**: Update the school's billing name.
- **Upload Brand Logo**: Upload your school's official logo (will appear on receipts, report cards, and email headers).

### 2. Module Toggles
Enable or disable specific features globally:
- If your school does not have a bus fleet, you can disable the Transport Module to hide it from student/parent menus.
- Toggle IoT Device Controller to enable smart laboratory settings.

### 3. Security Policies
- Set the maximum failed login attempts before lockout.
- Configure password expiration policies.
'''
    },
    {
      'id': 'roles-permissions',
      'category': 'Getting Started',
      'title': 'User Roles & Permissions',
      'readTime': '5 min read',
      'icon': Icons.verified_user_outlined,
      'summary': 'Learn about user roles and permission levels.',
      'content': '''
# Role-Based Access Control (RBAC)

To protect student privacy and ensure operational safety, School ERP uses a strict role-based authorization system.

---

## 👥 System Roles Hierarchy

1. **Super Admin**: Full global system configuration, infrastructure diagnostics, and school approval privileges.
2. **School Admin**: Full control over a single school instance, module toggling, fee configurations, and staff registration.
3. **Principal/Director**: General academic oversight, access to analytical reports, attendance logs, and fee reports.
4. **Teacher**: Manage classroom students, create online exams, schedule live classes, and upload topic files.
5. **Student / Parent**: Access courses, attempt homework, view grades, review fee invoices, and track transport buses.
6. **Support Staff (Finance, HR, Transport)**: Role-specific access to salary structures, attendance recording, or bus route tracking.
'''
    },
    {
      'id': 'add-staff',
      'category': 'User Management',
      'title': 'How to Add Staff Members',
      'readTime': '4 min read',
      'icon': Icons.person_add_alt_1_outlined,
      'summary': 'Step-by-step on creating accounts for teachers/principals and choosing role levels.',
      'content': '''
# How to Add Staff Members

Managing your school's faculty and administrative team is straightforward. Follow these steps to register a new staff member.

---

## 📝 Step-by-Step Registration Process

1. **Navigate to Staff Directory**:
   Go to User Management > Staff Directory on your left sidebar.
2. **Click "Add New Staff"**:
   Click the blue button in the top right corner.
3. **Fill Primary Information**:
   - Enter their full legal name, primary mobile number, and work email.
   - Choose their designation (e.g., Senior Teacher, Accountant, Principal).
4. **Assign Role Permissions**:
   Select the correct authorization level (Teacher, Finance Admin, Transport Admin).
5. **Save and Invite**:
   Click Save. The system will automatically generate a secure welcome link and send it to their registered email address.
'''
    },
    {
      'id': 'manage-roles',
      'category': 'User Management',
      'title': 'Managing Staff Access & Roles',
      'readTime': '3 min read',
      'icon': Icons.admin_panel_settings_outlined,
      'summary': 'Explaining permissions override matrix and access controls.',
      'content': '''
# Managing Staff Access & Roles

School ERP employs strict security principles. Here is how to configure custom permissions.

---

## 🛡️ Customizing Role Controls

1. **Access Role Manager**:
   Go to User Management > Roles & Permissions.
2. **Select Role**:
   Choose the role you wish to configure (e.g., Teacher, Principal).
3. **Toggle Permissions**:
   Turn permissions on or off for specific modules:
   - Academics: Edit courses, view timetables.
   - Finance: Generate invoices, edit fee receipts.
   - Transport: Assign buses, track live locations.
4. **Save Configuration**:
   Click Publish Changes to apply the security settings across your institution instantly.
'''
    },
    {
      'id': 'add-student',
      'category': 'Student Management',
      'title': 'Registering a New Student',
      'readTime': '5 min read',
      'icon': Icons.assignment_ind_outlined,
      'summary': 'Basic info, father/mother contact details, profile image upload, classroom assignment.',
      'content': '''
# Registering a New Student

Onboarding a student requires capturing their general registry info, parental contacts, and academic grouping.

---

## 📋 Admission Steps

1. **Access Admissions Desk**:
   Go to Student Management > New Admission.
2. **Personal Information**:
   Input full name, date of birth, gender, blood group, and residential address.
3. **Parent / Guardian Details**:
   - Provide primary guardian contact numbers and emails.
   - Set up their login credentials so they receive automated notifications.
4. **Academic Mapping**:
   Assign the student's Grade, Class Section, and Roll Number.
5. **Upload Documents**:
   Attach previous school certificates, ID cards, and a profile photo.
'''
    },
    {
      'id': 'update-student',
      'category': 'Student Management',
      'title': 'Updating Student Profile Details',
      'readTime': '3 min read',
      'icon': Icons.manage_accounts_outlined,
      'summary': 'Updating addresses, health files, or emergency contacts.',
      'content': '''
# Updating Student Profiles

When student details change, follow these steps to keep the registry database accurate.

---

## ✏️ Modifying Records

1. **Search for Student**:
   Go to Student Management > Student Directory and type their name or Roll Number.
2. **Open Profile**:
   Click the Edit action button next to their record.
3. **Apply Changes**:
   Modify fields (e.g. medical files, parent contact number, address).
4. **Audit Log Validation**:
   All changes are recorded in the system audit log with timestamps.
'''
    },
    {
      'id': 'take-attendance',
      'category': 'Attendance Management',
      'title': 'Taking Daily Student Attendance',
      'readTime': '4 min read',
      'icon': Icons.fact_check_outlined,
      'summary': 'How teachers mark Present/Absent/Late on the grid, and sending automatic SMS to parents.',
      'content': '''
# Taking Daily Student Attendance

Keeping accurate attendance logs is vital. Teachers can record daily rosters in under a minute.

---

## ⏱️ Taking Attendance

1. **Select Roster Grid**:
   Go to Attendance > Student Attendance. Select the Grade and Section.
2. **Mark Attendance**:
   The class student list is loaded. Tap the status buttons (Present, Absent, or Late) next to each student.
3. **Auto-Save & Notify**:
   Click Submit Attendance.
4. **Parent SMS Alerts**:
   If enabled, parents of absent students will instantly receive an automated SMS notification.
'''
    },
    {
      'id': 'attendance-reports',
      'category': 'Attendance Management',
      'title': 'Generating Attendance Analytics',
      'readTime': '3 min read',
      'icon': Icons.insights_outlined,
      'summary': 'Reviewing monthly attendance percentages and class performance.',
      'content': '''
# Generating Attendance Analytics

Analyze school attendance averages to identify chronic absence patterns.

---

## 📈 Creating Reports

1. **Navigate to Reports**:
   Go to Attendance > Attendance Reports.
2. **Filter Metrics**:
   Choose dates, class sections, or individual student IDs.
3. **Export Dashboard Data**:
   View graphical averages on screen, or export raw logs to PDF or Excel formats.
'''
    },
    {
      'id': 'create-exam',
      'category': 'Examination Management',
      'title': 'Creating Online and Offline Exams',
      'readTime': '5 min read',
      'icon': Icons.quiz_outlined,
      'summary': 'Setting up marks weightage, questions bank, and exam schedules.',
      'content': '''
# Creating Exams

Set up class schedules, total marks, and passing averages for academic evaluation.

---

## 📝 Creating the Exam Sheet

1. **Access Exam Manager**:
   Go to Examinations > Exam List and click Create Exam.
2. **Configure Parameters**:
   - Define exam name (e.g., Mid-Term Mathematics).
   - Set maximum marks and passing score thresholds.
   - Choose class grades and subject mapping.
3. **Define Schedule**:
   Specify exam dates, room numbers, and supervisor staff.
'''
    },
    {
      'id': 'grading-sheets',
      'category': 'Examination Management',
      'title': 'Entering Exam Marks & Publishing Grades',
      'readTime': '4 min read',
      'icon': Icons.workspace_premium_outlined,
      'summary': 'Inputting subject grades and printing student report cards.',
      'content': '''
# Entering Exam Marks & Grades

Once exams are complete, input grades and share reports instantly with students and parents.

---

## 🎓 Grading Steps

1. **Open Gradebook Grid**:
   Go to Examinations > Mark Entry. Select exam and class grade.
2. **Input Scores**:
   Type marks next to each student. The system will auto-calculate grades based on custom rules.
3. **Publish Report Cards**:
   Click Publish. Parents can immediately view report cards on their portal.
'''
    },
    {
      'id': 'fee-structure',
      'category': 'Fee Management',
      'title': 'Defining School Fee Categories',
      'readTime': '4 min read',
      'icon': Icons.account_balance_outlined,
      'summary': 'Setting up monthly tuition, library fees, and bus fees.',
      'content': '''
# Defining School Fee Categories

Configure flexible school pricing schedules and billing dates.

---

## 💳 Creating Fee Structures

1. **Open Setup Tab**:
   Go to Finance > Fee Setup.
2. **Define Fee Types**:
   Create categories (Tuition Fee, Transportation Fee, Admission Fee).
3. **Assign Classes**:
   Apply pricing schedules globally or customize rates for specific grades.
'''
    },
    {
      'id': 'collect-fees',
      'category': 'Fee Management',
      'title': 'Recording Student Fee Payments',
      'readTime': '4 min read',
      'icon': Icons.payments_outlined,
      'summary': 'Generating invoice receipts and tracking pending dues.',
      'content': '''
# Recording Student Fee Payments

Track transaction statuses, generate payment receipts, and reconcile pending school balances.

---

## 🧾 Collecting Payments

1. **Search Student Billing**:
   Go to Finance > Collect Fees and select a student.
2. **Record Transaction**:
   Select payment mode (Cash, Card, Online).
3. **Generate Invoice Receipt**:
   Click Submit. The system generates a digital receipt and emails it to the parent.
'''
    },
    {
      'id': 'create-routes',
      'category': 'Transport Management',
      'title': 'Setting Up Bus Routes & Stops',
      'readTime': '4 min read',
      'icon': Icons.add_road_outlined,
      'summary': 'Defining route numbers, driver assignments, and pick-up stops.',
      'content': '''
# Setting Up Bus Routes & Stops

Manage your institution's fleet routes and pickup locations.

---

## 🚌 Configuring Routes

1. **Access Transport Module**:
   Go to Transport > Routes.
2. **Add Route details**:
   Define route start points, destination stops, and driver assignments.
3. **Map Students**:
   Add student passengers to their nearest bus stop locations.
'''
    },
    {
      'id': 'track-bus',
      'category': 'Transport Management',
      'title': 'Tracking Live School Buses',
      'readTime': '3 min read',
      'icon': Icons.pin_drop_outlined,
      'summary': 'Integrating GPS tracking devices for parents.',
      'content': '''
# Tracking Live School Buses

Ensure student safety by tracking your vehicle locations in real-time.

---

## 📍 Live Tracking Setup

1. **Register GPS Devices**:
   Go to Transport > GPS Tracking.
2. **Track Location**:
   View real-time map positions on the administrator panel.
3. **Share Access**:
   Parents get access to live locations during active transport hours.
'''
    },
    {
      'id': 'add-books',
      'category': 'Library Management',
      'title': 'Adding Books to Library Inventory',
      'readTime': '3 min read',
      'icon': Icons.library_add_outlined,
      'summary': 'Cataloging ISBN, book title, author, copies available, and shelf location.',
      'content': '''
# Adding Books to Library Inventory

Keep your library database organized by cataloging new book editions.

---

## 📚 Book Cataloging

1. **Open Library Module**:
   Go to Library > Add Books.
2. **Fill Metadata Fields**:
   Input ISBN numbers, author names, publishers, and shelf rack locations.
3. **Record Copies**:
   Define total copies available for active student lending.
'''
    },
    {
      'id': 'issue-books',
      'category': 'Library Management',
      'title': 'Issuing & Returning Books',
      'readTime': '3 min read',
      'icon': Icons.swap_horiz_outlined,
      'summary': 'Scanning student card to check out books and applying late fines.',
      'content': '''
# Issuing & Returning Books

Track student checkout records and calculate late library return penalties.

---

## 🔄 Lending Process

1. **Issue Book**:
   Go to Library > Issue Book, search for a student, and scan the book barcode.
2. **Set Return Dates**:
   Select lending periods (default is 14 days).
3. **Process Returns**:
   Scan returned books to clear outstanding student logs.
'''
    },
    {
      'id': 'academic-reports',
      'category': 'Reports',
      'title': 'Exporting Student Academic Reports',
      'readTime': '4 min read',
      'icon': Icons.summarize_outlined,
      'summary': 'Exporting class grade distributions in PDF/Excel format.',
      'content': '''
# Exporting Student Academic Reports

Obtain comprehensive analytical performance summaries across various courses and grades.

---

## 📊 Exporting Report Cards

1. **Navigate to Reporting**:
   Go to Reports > Academic Performance.
2. **Filter Records**:
   Choose class levels, terms, or specific subject averages.
3. **Download**:
   Click Export to PDF or Export to Excel to save files locally.
'''
    },
    {
      'id': 'finance-ledger',
      'category': 'Reports',
      'title': 'Exporting Fee Collection Ledgers',
      'readTime': '4 min read',
      'icon': Icons.trending_up_outlined,
      'summary': 'Reconciling total fee revenues against pending dues.',
      'content': '''
# Exporting Fee Collection Ledgers

Review transaction streams, pending invoices, and total cash balances.

---

## 💵 Finance Summaries

1. **Open Financial Reports**:
   Go to Reports > Fee Ledger.
2. **Select Date Ranges**:
   Choose monthly or yearly billing statements.
3. **Export Ledger**:
   Generate CSV ledger balance sheets for school accounting purposes.
'''
    },
    {
      'id': 'brand-configuration',
      'category': 'Settings & Configuration',
      'title': 'Branding & Logo Configuration',
      'readTime': '3 min read',
      'icon': Icons.palette_outlined,
      'summary': 'Uploading custom logos and school headers.',
      'content': '''
# Branding & Logo Configuration

Customize the user interface themes and brand styles of your school portal.

---

## 🎨 Applying Custom Branding

1. **Open Settings Panel**:
   Go to Settings > Institution Profile.
2. **Upload Brand Logo**:
   Select high-resolution png logo files to display on invoices and reports.
3. **Choose Primary Accent Colors**:
   Save settings to apply custom styles across portals.
'''
    },
    {
      'id': 'security-lockout',
      'category': 'Settings & Configuration',
      'title': 'Configuring Security & Access Lockouts',
      'readTime': '3 min read',
      'icon': Icons.security_outlined,
      'summary': 'Setting up failed login limits and security parameters.',
      'content': '''
# Configuring Security Lockouts

Protect student records by enabling secure firewall lockout rules.

---

## 🔒 Enabling Lockouts

1. **Access Security Setup**:
   Go to Settings > Security Configurations.
2. **Configure Lockout Limits**:
   Set failed login attempt limits (default is 5).
3. **Define Lockout Durations**:
   Choose duration limits (e.g. block users for 30 minutes).
'''
    },
    {
      'id': 'install-app',
      'category': 'Mobile App',
      'title': 'Installing the School ERP App',
      'readTime': '3 min read',
      'icon': Icons.install_mobile_outlined,
      'summary': 'Downloading for Android and iOS systems.',
      'content': '''
# Installing the School ERP App

Stay connected by downloading our official mobile app on your smartphone device.

---

## 📱 Mobile Installation

1. **App Store Search**:
   Search for "School ERP" on the Google Play Store or Apple App Store.
2. **Download App**:
   Install the application.
3. **Portal Authentication**:
   Log in with your institution subdomain and student/teacher credentials.
'''
    },
    {
      'id': 'parent-notifications',
      'category': 'Mobile App',
      'title': 'Enabling Parent Push Notifications',
      'readTime': '3 min read',
      'icon': Icons.notifications_active_outlined,
      'summary': 'Getting instant alerts on attendance, exams, and fees.',
      'content': '''
# Enabling Parent Push Notifications

Ensure parents stay up to date with live push notification notifications.

---

## 🔔 Setting Up Notifications

1. **Enable App Permissions**:
   Allow notifications on your mobile device settings.
2. **Portal Notification Settings**:
   Toggle on notifications for attendance, fee payments, and exam reports.
'''
    },
    {
      'id': 'sms-gateway',
      'category': 'Integrations',
      'title': 'Configuring SMS Gateway Settings',
      'readTime': '4 min read',
      'icon': Icons.sms_outlined,
      'summary': 'Setting up API keys for Twilio or MSG91.',
      'content': '''
# Configuring SMS Gateways

Configure bulk SMS services to send instant text alerts to parents.

---

## 💬 Gateway Integration

1. **Access Integration Panel**:
   Go to Settings > Integrations > SMS Gateway.
2. **Select Provider**:
   Choose Twilio or MSG91 from the dropdown list.
3. **Input API Credentials**:
   Paste API keys and configure default sender IDs.
'''
    },
    {
      'id': 'payment-gateway',
      'category': 'Integrations',
      'title': 'Integrating Payment Gateways',
      'readTime': '4 min read',
      'icon': Icons.payment_outlined,
      'summary': 'Setting up Razorpay/Stripe details for online fees collection.',
      'content': '''
# Integrating Payment Gateways

Allow parents to pay invoices online securely via cards, UPI, or net banking.

---

## 💳 Payment Integrations

1. **Access Merchant Panel**:
   Go to Settings > Integrations > Payment Gateway.
2. **Choose Gateway**:
   Select Razorpay, Stripe, or Paytm.
3. **Enter Keys**:
   Input Merchant IDs, API Secret Keys, and select active currencies.
'''
    },
    {
      'id': 'general-faq',
      'category': 'FAQ',
      'title': 'General System FAQ',
      'readTime': '4 min read',
      'icon': Icons.help_center_outlined,
      'summary': 'Answering common login and account recovery questions.',
      'content': '''
# General System FAQ

Find answers to common operational questions.

---

## ❓ Common Questions

### 1. I forgot my admin credentials, how do I reset?
Click Forgot Password on the login page, enter your registered email, and input the OTP sent to your mailbox.

### 2. Can I disable modules that my school does not need?
Yes, go to Settings > Module Toggles to hide unused features like Transport or Library.
'''
    },
    {
      'id': 'onboarding-faq',
      'category': 'FAQ',
      'title': 'Subscription & Billing FAQ',
      'readTime': '3 min read',
      'icon': Icons.monetization_on_outlined,
      'summary': 'How payment plans work and upgrading subscriptions.',
      'content': '''
# Subscription & Billing FAQ

Answering common subscription management questions.

---

## ❓ Billing Questions

### 1. How do I upgrade my school subscription?
Go to Finance > Billing & Subscription and select your target student volume tier.

### 2. What happens if our subscription expires?
The school instance will transition to the expired status and all user logins will be locked out until payment is made.
'''
    }
  ];

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Getting Started',
      'icon': Icons.rocket_launch_outlined,
      'count': 5,
      'summary': 'New to School ERP? Start here. Set up your account and get familiar with the basics.'
    },
    {
      'name': 'User Management',
      'icon': Icons.people_outline,
      'count': 2,
      'summary': 'Manage users, roles, permissions and account settings.'
    },
    {
      'name': 'Student Management',
      'icon': Icons.person_outline,
      'count': 2,
      'summary': 'Add, edit and manage student information and profiles.'
    },
    {
      'name': 'Attendance Management',
      'icon': Icons.check_circle_outline,
      'count': 2,
      'summary': 'Track attendance, generate reports and send notifications.'
    },
    {
      'name': 'Examination Management',
      'icon': Icons.assignment_outlined,
      'count': 2,
      'summary': 'Create exams, mark results and generate performance reports.'
    },
    {
      'name': 'Fee Management',
      'icon': Icons.credit_card_outlined,
      'count': 2,
      'summary': 'Manage fee structures, collections, invoices and payments.'
    },
    {
      'name': 'Transport Management',
      'icon': Icons.directions_bus_outlined,
      'count': 2,
      'summary': 'Manage vehicles, routes, drivers and student transport.'
    },
    {
      'name': 'Library Management',
      'icon': Icons.book_outlined,
      'count': 2,
      'summary': 'Manage books, issue/return and library members.'
    },
    {
      'name': 'Reports',
      'icon': Icons.bar_chart_outlined,
      'count': 2,
      'summary': 'Generate and download insightful reports for your institution.'
    },
    {
      'name': 'Settings & Configuration',
      'icon': Icons.settings_outlined,
      'count': 2,
      'summary': 'Customize system settings and institution preferences.'
    },
    {
      'name': 'Mobile App',
      'icon': Icons.phone_android_outlined,
      'count': 2,
      'summary': 'Use the School ERP mobile app for on-the-go access.'
    },
    {
      'name': 'Integrations',
      'icon': Icons.integration_instructions_outlined,
      'count': 2,
      'summary': 'Integrate with third-party tools and services.'
    },
    {
      'name': 'FAQ',
      'icon': Icons.help_outline,
      'count': 2,
      'summary': 'Frequently asked questions about School ERP.'
    }
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedArticleId = widget.initialArticleId;
  }

  @override
  void didUpdateWidget(covariant SharedUserGuidesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != oldWidget.initialCategory ||
        widget.initialArticleId != oldWidget.initialArticleId) {
      setState(() {
        _selectedCategory = widget.initialCategory;
        _selectedArticleId = widget.initialArticleId;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _selectedArticleId = null;
    });
    _updateUrl();
  }

  void _navigateToArticle(String? articleId) {
    setState(() {
      _selectedArticleId = articleId;
    });
    _updateUrl();
  }

  void _updateUrl() {
    String path = '/user-guides';
    final queryParams = <String, String>{};
    if (_selectedCategory != null) {
      queryParams['category'] = _selectedCategory!;
    }
    if (_selectedArticleId != null) {
      queryParams['article'] = _selectedArticleId!;
    }
    
    final uri = Uri(path: path, queryParameters: queryParams.isNotEmpty ? queryParams : null);
    context.go(uri.toString());
  }

  List<Map<String, dynamic>> _getFilteredArticles() {
    return _articles.where((article) {
      final matchesCategory = _selectedCategory == null || article['category'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          article['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          article['summary'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;
    final name = widget.systemName ?? 'School ERP';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildNavbar(isDesktop, name),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Hero Header
            _buildHeroHeader(isDesktop),
            
            // 2. Main Content
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 20,
                vertical: 40,
              ),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Categories Sidebar
                        Expanded(
                          flex: 4,
                          child: _buildLeftSidebar(),
                        ),
                        const SizedBox(width: 40),
                        // Right Main Content Panel
                        Expanded(
                          flex: 8,
                          child: _buildRightPanel(),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildLeftSidebar(),
                        const SizedBox(height: 40),
                        _buildRightPanel(),
                      ],
                    ),
            ),
            
            // 3. Watch Video Tutorials CTA
            _buildVideoCtaBanner(),
            
            // 4. Footer
            _buildFooter(screenWidth >= 1100, name),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbar(bool isDesktop, String name) {
    final logoUrl = widget.systemLogo;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SafeArea(
        child: Row(
          children: [
            InkWell(
              onTap: () => context.go('/'),
              child: Row(
                children: [
                  if (logoUrl != null && logoUrl.isNotEmpty)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(
                        AppConfig.resolveUrl(logoUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.school_outlined,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        color: Color(0xFF6366F1),
                        size: 20,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Smart Management. Better Education.',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (isDesktop) ...[
              _buildNavbarLink('Home', () => context.go('/')),
              _buildNavbarLink('Features', () => context.go('/')),
              _buildNavbarLink('Modules', () => context.go('/')),
              _buildNavbarLink('Pricing', () => context.go('/')),
              _buildNavbarLink('About Us', () => context.go('/')),
              _buildNavbarLink('Contact Us', () => context.go('/contact')),
              const SizedBox(width: 24),
              OutlinedButton(
                onPressed: () => context.go('/login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text('Login', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => context.go('/get-started'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text('Get Started', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ] else
              IconButton(
                icon: const Icon(Icons.login, color: Color(0xFF6366F1)),
                onPressed: () => context.go('/login'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbarLink(String label, VoidCallback onTap, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: isActive ? const Color(0xFF4F46E5) : const Color(0xFF475569),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 16,
                color: const Color(0xFF4F46E5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(bool isDesktop) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 20,
        vertical: 60,
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildHeroLeftText(),
                ),
                const SizedBox(width: 40),
                Expanded(
                  flex: 5,
                  child: _buildHeroRightImage(),
                ),
              ],
            )
          : Column(
              children: [
                _buildHeroLeftText(),
                const SizedBox(height: 40),
                _buildHeroRightImage(),
              ],
            ),
    );
  }

  Widget _buildHeroLeftText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'USER GUIDES',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4F46E5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            text: 'User ',
            style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            children: [
              TextSpan(
                text: 'Guides',
                style: TextStyle(color: const Color(0xFF6366F1)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Step-by-step guides to help you understand and make the most out of School ERP.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: const Color(0xFF64748B),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        // Search Input Field
        Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                // Reset selected state to overview if searching globally
                if (_selectedCategory == null && _selectedArticleId != null) {
                  _selectedArticleId = null;
                }
              });
            },
            decoration: InputDecoration(
              hintText: 'Search for guides, topics or keywords...',
              hintStyle: GoogleFonts.dmSans(color: const Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroRightImage() {
    final imgUrl = widget.illustrationUrl ?? 'assets/images/user_guide_illustration.png';
    return Center(
      child: Image.asset(
        imgUrl,
        width: 380,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 380,
          height: 250,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2F6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.menu_book_outlined, size: 80, color: Color(0xFF6366F1)),
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Categories list card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Guide Categories',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // "All Guides" toggle link
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: InkWell(
                  onTap: () => _navigateToCategory(null),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedCategory == null && _selectedArticleId == null ? const Color(0xFFEEF2F6) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.grid_view_outlined,
                          size: 16,
                          color: _selectedCategory == null && _selectedArticleId == null ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All Categories',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: _selectedCategory == null && _selectedArticleId == null ? FontWeight.bold : FontWeight.w500,
                              color: _selectedCategory == null && _selectedArticleId == null ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 16),
              // Specific categories
              ..._categories.map((cat) {
                final categoryName = cat['name'] as String;
                final isSelected = _selectedCategory == categoryName;
                final icon = cat['icon'] as IconData;
                final count = cat['count'] as int;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: InkWell(
                    onTap: () => _navigateToCategory(categoryName),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEEF2F6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              categoryName,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF6366F1).withOpacity(0.1) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Help Card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2F6).withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.headset_mic_outlined, color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(height: 16),
              Text(
                'Still Need Help?',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Can\'t find what you\'re looking for? Our support team is here to help.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Contact Support',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    AppConfig.contactPhone,
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    // If an article is active, show the detail view
    if (_selectedArticleId != null) {
      final article = _articles.firstWhere((a) => a['id'] == _selectedArticleId, orElse: () => _articles[0]);
      return _buildArticleDetailView(article);
    }
    
    // If a category is selected (and not all), show the category items list
    if (_selectedCategory != null) {
      final filteredFaqs = _getFilteredArticles();
      return _buildCategoryListView(filteredFaqs);
    }

    // Default overview layout (All Categories & Highlights)
    return _buildOverviewLayout();
  }

  Widget _buildOverviewLayout() {
    final gettingStartedFaqs = _articles.where((a) => a['category'] == 'Getting Started').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Getting Started highlighted header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_outlined, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 12),
                Text(
                  'Getting Started',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => _navigateToCategory('Getting Started'),
              child: Row(
                children: [
                  Text(
                    'View all (5)',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF6366F1)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 2. Getting Started cards row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: gettingStartedFaqs.map((faq) {
              return Container(
                width: 230,
                margin: const EdgeInsets.only(right: 16, bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => _navigateToArticle(faq['id']),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(faq['icon'], color: const Color(0xFF6366F1), size: 24),
                          const Icon(Icons.bookmark_outline, color: Color(0xFF94A3B8), size: 18),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        faq['title'],
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        faq['summary'],
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Text(
                            faq['readTime'],
                            style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 40),
        
        // 3. Grid of All Categories
        Text(
          'All User Guide Categories',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width >= 1200 ? 3 : (MediaQuery.of(context).size.width >= 700 ? 2 : 1),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 180,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final name = cat['name'] as String;
            final count = cat['count'] as int;
            final summary = cat['summary'] as String;
            final icon = cat['icon'] as IconData;

            return InkWell(
              onTap: () => _navigateToCategory(name),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward, color: Color(0xFF94A3B8), size: 14),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        summary,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$count Articles',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryListView(List<Map<String, dynamic>> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back navigation header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF475569)),
              onPressed: () => _navigateToCategory(null),
            ),
            const SizedBox(width: 8),
            Text(
              _selectedCategory ?? '',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        if (filtered.isEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'No guides found in this category.',
                style: GoogleFonts.dmSans(color: const Color(0xFF64748B)),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final art = filtered[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: InkWell(
                  onTap: () => _navigateToArticle(art['id']),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(art['icon'], color: const Color(0xFF6366F1), size: 24),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                art['title'],
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                art['summary'],
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 6),
                                  Text(
                                    art['readTime'],
                                    style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMarkdownLine(String text, TextStyle baseStyle) {
    if (!text.contains('**')) {
      return Text(
        text,
        style: baseStyle,
      );
    }

    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: isBold
              ? baseStyle.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))
              : baseStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans,
      ),
    );
  }

  Widget _buildArticleDetailView(Map<String, dynamic> article) {
    final content = article['content'] as String;
    final List<String> lines = content.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back header links
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF475569)),
              onPressed: () => _navigateToArticle(null),
            ),
            const SizedBox(width: 8),
            Text(
              'Back to ${article['category']}',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Article Card Layout
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Metadata
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      article['category'],
                      style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    article['readTime'],
                    style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Custom Render Markdown-like Rich Text
              ...lines.map((line) {
                final trimmed = line.trim();
                if (trimmed.startsWith('# ')) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      trimmed.substring(2),
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  );
                } else if (trimmed.startsWith('## ')) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 8),
                    child: Text(
                      trimmed.substring(3),
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  );
                } else if (trimmed.startsWith('### ')) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      trimmed.substring(4),
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                    ),
                  );
                } else if (trimmed.startsWith('- ')) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Expanded(
                          child: _buildMarkdownLine(
                            trimmed.substring(2),
                            GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (trimmed.startsWith('1. ') || trimmed.startsWith('2. ') || trimmed.startsWith('3. ') || trimmed.startsWith('4. ')) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${trimmed[0]}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: _buildMarkdownLine(
                            trimmed.substring(3),
                            GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (trimmed == '---') {
                  return const Divider(height: 32);
                } else if (trimmed.isEmpty) {
                  return const SizedBox(height: 12);
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMarkdownLine(
                      trimmed,
                      GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF475569), height: 1.6),
                    ),
                  );
                }
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCtaBanner() {
    final videoImg = widget.videoIllustrationUrl ?? 'assets/images/video_tutorials_illustration.png';
    return Container(
      width: double.infinity,
      color: const Color(0xFFEEF2F6).withOpacity(0.6),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              return isWide
                  ? Row(
                      children: [
                        Image.asset(
                          videoImg,
                          width: 140,
                          height: 110,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 140,
                            height: 110,
                            color: const Color(0xFFCBD5E1),
                            child: const Icon(Icons.play_circle_fill, size: 40, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 40),
                        Expanded(
                          child: _buildVideoCtaText(),
                        ),
                        const SizedBox(width: 40),
                        _buildVideoCtaButton(),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(videoImg, width: 120, height: 90, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 24),
                        _buildVideoCtaText(),
                        const SizedBox(height: 24),
                        _buildVideoCtaButton(),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCtaText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New to School ERP?',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Watch our step-by-step video tutorials to quickly learn how to use all features and modules.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCtaButton() {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Watch Video Tutorials',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 16),
        ],
      ),
    );
  }

  Widget _buildFooter(bool showWideFooter, String name) {
    return Container(
      color: const Color(0xFF0F1026),
      padding: EdgeInsets.symmetric(
        horizontal: showWideFooter ? 64 : 24,
        vertical: 60,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: showWideFooter ? 3 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'An all-in-one school management system designed to simplify administration, improve communication and enhance overall efficiency.',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: Colors.white60,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildSocialIcon(Icons.facebook),
                        _buildSocialIcon(Icons.camera_alt),
                        _buildSocialIcon(Icons.alternate_email),
                        _buildSocialIcon(Icons.play_circle_filled),
                      ],
                    ),
                  ],
                ),
              ),
              if (showWideFooter) ...[
                const SizedBox(width: 48),
                Expanded(
                  flex: 2,
                  child: _buildFooterColumn('Quick Links', const ['Home', 'Features', 'Modules', 'Pricing', 'About Us', 'Contact Us', 'FAQ', 'Help Center']),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 2,
                  child: _buildFooterColumn('Modules', const ['Student Management', 'Attendance Management', 'Examination Management', 'Fee Management', 'Transport Management', 'Library Management']),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 2,
                  child: _buildFooterColumn('Support', const ['Help Center', 'User Guides', 'FAQ\'s', 'Privacy Policy', 'Terms & Conditions']),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Us',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFooterContactItem(Icons.location_on_outlined, AppConfig.contactAddress),
                      _buildFooterContactItem(Icons.email_outlined, AppConfig.contactEmail),
                      _buildFooterContactItem(Icons.phone_outlined, AppConfig.contactPhone),
                      _buildFooterContactItem(Icons.access_time_outlined, 'Mon - Sat: 9:00 AM - 6:00 PM'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (!showWideFooter) ...[
            const SizedBox(height: 32),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),
            Wrap(
              spacing: 48,
              runSpacing: 32,
              children: [
                SizedBox(
                  width: 180,
                  child: _buildFooterColumn('Quick Links', const ['Home', 'Features', 'Modules', 'Pricing', 'About Us', 'Contact Us', 'FAQ', 'Help Center']),
                ),
                SizedBox(
                  width: 220,
                  child: _buildFooterColumn('Modules', const ['Student Management', 'Attendance Management', 'Examination Management', 'Fee Management', 'Transport Management', 'Library Management']),
                ),
                SizedBox(
                  width: 180,
                  child: _buildFooterColumn('Support', const ['Help Center', 'User Guides', 'FAQ\'s', 'Privacy Policy', 'Terms & Conditions']),
                ),
                SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Us',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFooterContactItem(Icons.location_on_outlined, AppConfig.contactAddress),
                      _buildFooterContactItem(Icons.email_outlined, AppConfig.contactEmail),
                      _buildFooterContactItem(Icons.phone_outlined, AppConfig.contactPhone),
                      _buildFooterContactItem(Icons.access_time_outlined, 'Mon - Sat: 9:00 AM - 6:00 PM'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 48),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2025 $name. All rights reserved.',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: Colors.white38,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.white54, size: 16),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  Widget _buildFooterColumn(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  if (item == 'Contact Us') {
                    context.go('/contact');
                  } else if (item == 'Home') {
                    context.go('/');
                  } else if (item == 'Privacy Policy') {
                    context.go('/privacy-policy');
                  } else if (item == 'Terms & Conditions') {
                    context.go('/terms-conditions');
                  } else if (item == 'FAQ') {
                    context.go('/faq');
                  } else if (item == 'FAQ\'s') {
                    context.go('/faq');
                  } else if (item == 'Help Center') {
                    context.go('/help-center');
                  } else if (item == 'User Guides') {
                    context.go('/user-guides');
                  }
                },
                child: Text(
                  item,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildFooterContactItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
