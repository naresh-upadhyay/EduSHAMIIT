import 'package:edu_shamiit_core/services/api_service.dart';

class HRTemplateVariable {
  final String tag;
  final String label;
  final String category;
  final String sampleValue;

  const HRTemplateVariable({
    required this.tag,
    required this.label,
    required this.category,
    required this.sampleValue,
  });
}

class HRTemplatePreset {
  final String code;
  final String name;
  final String type;
  final String category;
  final String description;
  final String contentHtml;
  final List<String> variables;

  const HRTemplatePreset({
    required this.code,
    required this.name,
    required this.type,
    required this.category,
    required this.description,
    required this.contentHtml,
    required this.variables,
  });

  factory HRTemplatePreset.fromJson(Map<String, dynamic> json) {
    final rawVars = json['variables'];
    final List<String> varsList = [];
    if (rawVars is List) {
      for (final v in rawVars) {
        varsList.add(v.toString());
      }
    }
    return HRTemplatePreset(
      code: json['template_code']?.toString() ?? '',
      name: json['template_name']?.toString() ?? '',
      type: json['template_type']?.toString() ?? 'Custom',
      category: json['category_name']?.toString() ?? 'Administration',
      description: json['description']?.toString() ?? '',
      contentHtml: json['content_html']?.toString() ?? '',
      variables: varsList,
    );
  }
}

class HRTemplatePresets {
  static const List<HRTemplateVariable> allVariables = [
    // Employee
    HRTemplateVariable(
      tag: 'employee_name',
      label: 'Employee Full Name',
      category: 'Employee',
      sampleValue: 'Dr. Rajesh Verma',
    ),
    HRTemplateVariable(
      tag: 'employee_id',
      label: 'Staff / Employee ID',
      category: 'Employee',
      sampleValue: 'EMP-2024-042',
    ),
    HRTemplateVariable(
      tag: 'employee_email',
      label: 'Employee Email',
      category: 'Employee',
      sampleValue: 'rajesh.verma@institution.edu.in',
    ),
    HRTemplateVariable(
      tag: 'employee_phone',
      label: 'Employee Phone',
      category: 'Employee',
      sampleValue: '+91 98765 43210',
    ),
    HRTemplateVariable(
      tag: 'employee_address',
      label: 'Residential Address',
      category: 'Employee',
      sampleValue: 'Flat 402, Green Avenue Towers, Knowledge Park, City',
    ),

    // Job & Department
    HRTemplateVariable(
      tag: 'designation',
      label: 'Official Designation',
      category: 'Job & Role',
      sampleValue: 'Senior Faculty & Academic Coordinator',
    ),
    HRTemplateVariable(
      tag: 'department',
      label: 'Department Unit',
      category: 'Job & Role',
      sampleValue: 'Department of Academics & Sciences',
    ),
    HRTemplateVariable(
      tag: 'reporting_manager',
      label: 'Reporting Manager / Dean',
      category: 'Job & Role',
      sampleValue: 'Prof. Alok Mukherjee (Dean of Academics)',
    ),
    HRTemplateVariable(
      tag: 'work_location',
      label: 'Campus Location',
      category: 'Job & Role',
      sampleValue: 'Main Campus, North Block',
    ),

    // Dates & Terms
    HRTemplateVariable(
      tag: 'joining_date',
      label: 'Joining Date',
      category: 'Dates & Terms',
      sampleValue: '12 July 2021',
    ),
    HRTemplateVariable(
      tag: 'effective_date',
      label: 'Effective Date',
      category: 'Dates & Terms',
      sampleValue: '24 September 2026',
    ),
    HRTemplateVariable(
      tag: 'relieving_date',
      label: 'Relieving / End Date',
      category: 'Dates & Terms',
      sampleValue: '30 September 2026',
    ),
    HRTemplateVariable(
      tag: 'salary',
      label: 'Remuneration / CTC',
      category: 'Dates & Terms',
      sampleValue: '₹ 10,20,000 / annum (₹ 85,000 / month)',
    ),
    HRTemplateVariable(
      tag: 'probation_period',
      label: 'Probation Duration',
      category: 'Dates & Terms',
      sampleValue: 'Six (6) Months',
    ),
    HRTemplateVariable(
      tag: 'notice_period',
      label: 'Notice Period Term',
      category: 'Dates & Terms',
      sampleValue: 'Three (3) Months',
    ),

    // Disciplinary & Warning Specifics
    HRTemplateVariable(
      tag: 'warning_level',
      label: 'Disciplinary Warning Level',
      category: 'Disciplinary & Review',
      sampleValue: 'First Formal Written Warning',
    ),
    HRTemplateVariable(
      tag: 'incident_date',
      label: 'Date of Infraction',
      category: 'Disciplinary & Review',
      sampleValue: '18 September 2026',
    ),
    HRTemplateVariable(
      tag: 'policy_violated',
      label: 'Specific Policy Violated',
      category: 'Disciplinary & Review',
      sampleValue: 'Section 4.2 (Attendance & Professional Decorum Policy)',
    ),
    HRTemplateVariable(
      tag: 'reason_for_warning',
      label: 'Detailed Reason / Finding',
      category: 'Disciplinary & Review',
      sampleValue: 'Repeated unexcused absenteeism and non-submission of student evaluation gradebooks by deadline',
    ),
    HRTemplateVariable(
      tag: 'corrective_action_plan',
      label: 'Mandatory Corrective Action',
      category: 'Disciplinary & Review',
      sampleValue: 'Immediate adherence to daily biometric schedule and completion of pending logs within 5 working days',
    ),
    HRTemplateVariable(
      tag: 'review_period',
      label: 'Observation Review Period',
      category: 'Disciplinary & Review',
      sampleValue: 'Thirty (30) Calendar Days',
    ),

    // Organization
    HRTemplateVariable(
      tag: 'institution_name',
      label: 'Institution Name',
      category: 'Organization',
      sampleValue: 'Greenfield International Institution',
    ),
    HRTemplateVariable(
      tag: 'campus_address',
      label: 'Institution Full Address',
      category: 'Organization',
      sampleValue: 'Plot 14, Institutional Area, Sector 62, NCR Region',
    ),
    HRTemplateVariable(
      tag: 'authorized_signatory_name',
      label: 'Signatory Name',
      category: 'Organization',
      sampleValue: 'Dr. Arindam Sen, Ph.D.',
    ),
    HRTemplateVariable(
      tag: 'authorized_signatory_title',
      label: 'Signatory Title',
      category: 'Organization',
      sampleValue: 'Director of Human Resources & Institutional Governance',
    ),
  ];

  static const List<HRTemplatePreset> presets = [
    // 1. Warning Letter
    HRTemplatePreset(
      code: 'TMPL-WARN',
      name: 'Formal Disciplinary & Performance Warning Letter',
      type: 'Warning Letter',
      category: 'Employee Policies',
      description: 'Official notice detailing institutional policy infraction, corrective action plan, and timeline for compliance.',
      variables: [
        'employee_name', 'employee_id', 'designation', 'department',
        'effective_date', 'incident_date', 'policy_violated', 'warning_level',
        'reason_for_warning', 'corrective_action_plan', 'review_period',
        'institution_name', 'reporting_manager', 'authorized_signatory_name',
      ],
      contentHtml: '''
<p><strong>CONFIDENTIAL & OFFICIAL NOTIFICATION</strong></p>
<p><strong>To:</strong> {{employee_name}}<br>
<strong>Staff Identification Code:</strong> {{employee_id}}<br>
<strong>Designation:</strong> {{designation}}<br>
<strong>Department:</strong> {{department}}<br>
<strong>Date of Notice:</strong> {{effective_date}}</p>

<p><strong>SUBJECT: OFFICIAL DISCIPLINARY NOTICE — {{warning_level}}</strong></p>

<p>Dear {{employee_name}},</p>

<p>This formal communication constitutes an official <strong>{{warning_level}}</strong> issued in accordance with the Human Resources Governance Guidelines and the Institutional Code of Conduct of <strong>{{institution_name}}</strong>.</p>

<p>Following a formal review conducted by the Academic Directorate and the Department of Human Resources, it has been established that on or around <strong>{{incident_date}}</strong>, your professional conduct and operational delivery breached institutional standards, specifically regarding:</p>

<p><strong>Infraction & Finding:</strong><br>
<em>{{reason_for_warning}}</em></p>

<p>This behavior directly contravenes <strong>{{policy_violated}}</strong>, which every member of {{institution_name}} is required to uphold unconditionally.</p>

<p><strong>Mandatory Corrective Action Plan (CAP):</strong></p>
<ol>
  <li><strong>Immediate Rectification:</strong> You are instructed to execute the following corrective steps without delay: {{corrective_action_plan}}.</li>
  <li><strong>Supervisory Alignment:</strong> You will meet with your reporting authority, <strong>{{reporting_manager}}</strong>, on a weekly basis to review task milestones and punctuality.</li>
  <li><strong>Monitoring Period:</strong> Your performance and conduct will remain under active administrative review for a duration of <strong>{{review_period}}</strong> from the date of this letter.</li>
</ol>

<p>Please note that <strong>{{institution_name}}</strong> values accountability and professionalism. Failure to demonstrate immediate, sustained, and verifiable improvement during this observation window, or any recurrence of similar infractions, will result in escalation to severe disciplinary proceedings, which may include formal suspension without pay or termination of employment contract.</p>

<p>You are requested to endorse the acknowledgement below and return the signed duplicate copy to the Human Resources Directorate within forty-eight (48) hours of receipt.</p>

<p>Sincerely,</p>
<p><strong>{{authorized_signatory_name}}</strong><br>
Director of Human Resources & Governance<br>
{{institution_name}}</p>

<hr>
<p><strong>EMPLOYEE ACKNOWLEDGEMENT & AFFIRMATION</strong><br>
I, {{employee_name}}, acknowledge that I have received this formal warning letter, have read and understood its contents, and commit to fulfilling the corrective directives outlined herein.</p>
<p>Employee Signature: _______________________ &nbsp;&nbsp;&nbsp;&nbsp; Date: _______________</p>
''',
    ),

    // 2. Offer Letter
    HRTemplatePreset(
      code: 'TMPL-OFFER',
      name: 'Faculty & Professional Staff Offer of Employment',
      type: 'Offer Letter',
      category: 'Recruitment',
      description: 'Comprehensive employment offer covering remuneration CTC breakdown, designation, and onboarding conditions.',
      variables: [
        'employee_name', 'employee_address', 'employee_phone', 'employee_email',
        'designation', 'department', 'effective_date', 'joining_date',
        'salary', 'reporting_manager', 'probation_period', 'institution_name',
      ],
      contentHtml: '''
<p><strong>Date of Issuance:</strong> {{effective_date}}</p>
<p><strong>Private & Confidential</strong></p>
<p><strong>To:</strong><br>
<strong>{{employee_name}}</strong><br>
{{employee_address}}<br>
Phone: {{employee_phone}} | Email: {{employee_email}}</p>

<p><strong>SUBJECT: OFFER OF EMPLOYMENT FOR THE POSITION OF {{designation}}</strong></p>

<p>Dear {{employee_name}},</p>

<p>On behalf of the Board of Trustees and Leadership Council of <strong>{{institution_name}}</strong>, we are delighted to offer you the position of <strong>{{designation}}</strong> within our <strong>{{department}}</strong>.</p>

<p>We were thoroughly impressed by your instructional competence, academic accomplishments, and dedication to institutional excellence during our selection process. We are confident that you will make a profound and lasting contribution to our campus community.</p>

<p><strong>Key Terms of the Employment Offer:</strong></p>
<ul>
  <li><strong>Designation & Title:</strong> {{designation}}</li>
  <li><strong>Department / Unit:</strong> {{department}}</li>
  <li><strong>Date of Commencement:</strong> On or before <strong>{{joining_date}}</strong></li>
  <li><strong>Reporting Authority:</strong> You will report directly to <strong>{{reporting_manager}}</strong></li>
  <li><strong>Annual Gross Compensation (CTC):</strong> <strong>{{salary}}</strong>, subject to statutory deductions as detailed in the compensation annexure.</li>
  <li><strong>Probation Period:</strong> You will be on probationary evaluation for <strong>{{probation_period}}</strong>, upon the satisfactory completion of which your appointment will be formally confirmed in writing.</li>
</ul>

<p><strong>Conditions Precedent:</strong><br>
This offer is contingent upon successful verification of your academic degrees, previous service certificates, reference endorsements, and submission of mandatory statutory identity documents.</p>

<p>To confirm your acceptance of this offer, please sign and return a duplicate copy of this letter along with your anticipated date of joining by {{effective_date}}.</p>

<p>We look forward to welcoming you to {{institution_name}} and wish you an inspiring and distinguished career with us.</p>

<p>Warm regards,</p>
<p><strong>Head of Human Resources & Talent Acquisition</strong><br>
{{institution_name}}</p>
''',
    ),

    // 3. Appointment Letter
    HRTemplatePreset(
      code: 'TMPL-APPT',
      name: 'Official Letter of Appointment & Employment Contract',
      type: 'Appointment Letter',
      category: 'Employee Policies',
      description: 'Formal appointment contract outlining duties, probation clauses, code of conduct, and notice periods.',
      variables: [
        'employee_name', 'employee_id', 'designation', 'department',
        'joining_date', 'effective_date', 'salary', 'reporting_manager',
        'probation_period', 'notice_period', 'institution_name',
      ],
      contentHtml: '''
<p><strong>Ref:</strong> {{template_code}}/APPT/2026<br>
<strong>Date:</strong> {{effective_date}}</p>

<p><strong>To:</strong><br>
<strong>{{employee_name}}</strong> (Staff Code: {{employee_id}})<br>
Designation: {{designation}}<br>
Department: {{department}}</p>

<p><strong>SUBJECT: FORMAL LETTER OF APPOINTMENT & SERVICE CONTRACT</strong></p>

<p>Dear {{employee_name}},</p>

<p>Pursuant to your acceptance of our Employment Offer dated {{effective_date}}, the Management of <strong>{{institution_name}}</strong> is pleased to formally appoint you as <strong>{{designation}}</strong> in the <strong>{{department}}</strong> with effect from <strong>{{joining_date}}</strong>.</p>

<p><strong>Terms and Conditions of Employment:</strong></p>
<ol>
  <li><strong>Duties & Responsibilities:</strong> You shall perform all academic instruction, mentoring, curriculum review, examination governance, and student welfare assignments delegated by {{reporting_manager}} and the Institutional Directorate.</li>
  <li><strong>Remuneration & Pay Scale:</strong> Your total annual remuneration package shall be <strong>{{salary}}</strong>, payable on a monthly pro-rata basis on the final working day of each calendar month.</li>
  <li><strong>Probation & Performance Review:</strong> You will be on probation for an initial duration of <strong>{{probation_period}}</strong>. During probation, either party may terminate this agreement by providing thirty (30) days' written notice or equivalent base salary in lieu thereof.</li>
  <li><strong>Notice Period on Confirmation:</strong> Following confirmation, the mandatory notice period shall be <strong>{{notice_period}}</strong>. Notice periods may not coincide with active academic term examinations.</li>
  <li><strong>Institutional Ethics & Decorum:</strong> You shall at all times observe the highest standards of professional ethics, student safeguarding, and academic honesty as stipulated in the Institutional Employee Handbook.</li>
</ol>

<p>Please endorse your signature below to signify your acceptance of these service terms.</p>

<p>Yours faithfully,</p>
<p><strong>Director General & President</strong><br>
{{institution_name}}</p>
''',
    ),

    // 4. Experience Letter
    HRTemplatePreset(
      code: 'TMPL-EXP',
      name: 'Employee Experience & Service Conduct Certificate',
      type: 'Experience Letter',
      category: 'Administration',
      description: 'Official service certificate verifying employment tenure, designations held, and conduct assessment.',
      variables: [
        'employee_name', 'employee_id', 'designation', 'department',
        'joining_date', 'relieving_date', 'effective_date', 'institution_name',
      ],
      contentHtml: '''
<p><strong>TO WHOMSOEVER IT MAY CONCERN</strong></p>

<p><strong>Ref:</strong> {{template_code}}/EXP/2026<br>
<strong>Date of Issuance:</strong> {{effective_date}}</p>

<p>This is to certify that <strong>{{employee_name}}</strong> (Staff Identification: <strong>{{employee_id}}</strong>) was employed with <strong>{{institution_name}}</strong> as <strong>{{designation}}</strong> in the <strong>{{department}}</strong> from <strong>{{joining_date}}</strong> to <strong>{{relieving_date}}</strong>.</p>

<p>Throughout their tenure, {{employee_name}} demonstrated commendable professional dedication, intellectual rigor, and an unwavering commitment to pedagogical and operational excellence. They actively contributed to departmental curricula, research symposia, and institutional development initiatives.</p>

<p>During their tenure of service with us, we found them to be diligent, conscientious, and capable. Their character was unblemished, and their interpersonal relationships with colleagues, students, and administration were consistently cordial.</p>

<p>All institutional obligations and accounts have been fully cleared, and they are relieved of all institutional liabilities. We express our sincere appreciation for their contributions and wish them distinguished success in all their future academic and professional endeavors.</p>

<p>Given under the Seal of the Institution on this day, {{effective_date}}.</p>

<p><strong>Registrar & Chief Administrative Officer</strong><br>
{{institution_name}}</p>
''',
    ),

    // 5. Relieving Letter
    HRTemplatePreset(
      code: 'TMPL-REL',
      name: 'Official Relieving Order & Clearance Certificate',
      type: 'Relieving Letter',
      category: 'Administration',
      description: 'Formal relieving order confirming resignation acceptance, last working day, and asset clearance.',
      variables: [
        'employee_name', 'employee_id', 'designation', 'department',
        'effective_date', 'relieving_date', 'institution_name',
      ],
      contentHtml: '''
<p><strong>Ref:</strong> {{template_code}}/REL/2026<br>
<strong>Date:</strong> {{effective_date}}</p>

<p><strong>To:</strong><br>
<strong>{{employee_name}}</strong><br>
Staff Identification: {{employee_id}}<br>
Designation: {{designation}}<br>
Department: {{department}}</p>

<p><strong>SUBJECT: RELIEVING ORDER FROM INSTITUTIONAL SERVICES</strong></p>

<p>Dear {{employee_name}},</p>

<p>With reference to your formal resignation letter and subsequent handover proceedings, this is to formally certify that your resignation has been accepted by the Competent Authority of <strong>{{institution_name}}</strong>.</p>

<p>You are hereby officially relieved from your duties and responsibilities as <strong>{{designation}}</strong> in the <strong>{{department}}</strong> with effect from the close of business hours on <strong>{{relieving_date}}</strong>.</p>

<p>We confirm that you have completed comprehensive departmental transition, submitted all examination records, returned campus hardware and security access tokens, and secured Full & Final No-Dues Clearance from all administrative divisions including Accounts, IT, and Central Library.</p>

<p>We thank you for your committed service and wish you continued success, accomplishment, and fulfillment in your subsequent career journey.</p>

<p>Sincerely yours,</p>
<p><strong>Head of Human Resources</strong><br>
{{institution_name}}</p>
''',
    ),

    // 6. NDA & Confidentiality
    HRTemplatePreset(
      code: 'TMPL-NDA',
      name: 'Institutional Non-Disclosure & Intellectual Property Agreement',
      type: 'NDA & Confidentiality',
      category: 'Legal & Compliance',
      description: 'Legally binding non-disclosure covenant safeguarding student data, IP, exams, and proprietary curricula.',
      variables: [
        'employee_name', 'employee_id', 'employee_address', 'designation',
        'department', 'effective_date', 'institution_name',
      ],
      contentHtml: '''
<p><strong>INSTITUTIONAL NON-DISCLOSURE AND PROPRIETARY INFORMATION COVENANT</strong></p>

<p>This Non-Disclosure Agreement ("Agreement") is entered into on <strong>{{effective_date}}</strong> by and between <strong>{{institution_name}}</strong> ("Institution") and <strong>{{employee_name}}</strong> (Staff Code: <strong>{{employee_id}}</strong>, residing at {{employee_address}}), hereinafter designated as "Recipient".</p>

<p><strong>1. Scope of Confidential Information:</strong><br>
The Recipient acknowledges that in the course of discharging duties as {{designation}} in the {{department}}, they will have access to sensitive, proprietary, non-public data, including student personal dossiers, academic assessment banks, internal administrative strategies, research intellectual property, and institutional financials.</p>

<p><strong>2. Covenant of Confidentiality:</strong><br>
The Recipient covenants and agrees to preserve the absolute confidentiality of all such information and shall not, directly or indirectly, publish, disseminate, photocopy, or disclose any portion thereof to any unauthorized person or entity without the prior written authorization of the Director General of {{institution_name}}.</p>

<p><strong>3. Intellectual Property Assignment:</strong><br>
All curriculum designs, online learning modules, software codebases, and instructional materials authored by the Recipient during the term of employment utilizing institutional facilities shall constitute works made for hire and remain the absolute and exclusive property of {{institution_name}}.</p>

<p><strong>4. Injunctive Relief & Survival:</strong><br>
The covenants contained herein shall survive the termination or cessation of employment for a minimum period of three (3) years. Any breach shall entitle the Institution to seek immediate injunctive relief and damages in a court of competent jurisdiction.</p>

<p><strong>Executed by the Parties:</strong></p>
<p>For {{institution_name}}: _____________________ &nbsp;&nbsp;&nbsp;&nbsp; Recipient: {{employee_name}}</p>
''',
    ),

    // 7. Code of Conduct
    HRTemplatePreset(
      code: 'TMPL-COC',
      name: 'Institutional Code of Ethical Conduct & Professional Decorum',
      type: 'Code of Conduct',
      category: 'Employee Policies',
      description: 'Comprehensive institutional ethics policy covering child safety, anti-harassment, and professional decorum.',
      variables: [
        'employee_name', 'employee_id', 'designation', 'effective_date', 'institution_name',
      ],
      contentHtml: '''
<p><strong>INSTITUTIONAL CODE OF ETHICAL CONDUCT & WORKPLACE DECORUM</strong></p>

<p><strong>Applicability:</strong> Mandatory for all Academic, Administrative, and Operational Personnel<br>
<strong>Effective Date:</strong> {{effective_date}}<br>
<strong>Issued by:</strong> Governing Council of {{institution_name}}</p>

<p><strong>1. Fundamental Principles:</strong><br>
Every employee of <strong>{{institution_name}}</strong> is an ambassador of academic integrity, moral rectitude, and student welfare. Professional conduct must at all times inspire trust and reflect dignity.</p>

<p><strong>2. Child Safeguarding & Zero-Tolerance Harassment Policy:</strong><br>
The Institution enforces strict compliance with statutory Child Protection Directives and Workplace Harassment Laws. Corporal punishment, verbal abuse, discriminatory remarks, or unauthorized personal contact with students is strictly forbidden and constitutes gross misconduct resulting in summary termination and statutory prosecution.</p>

<p><strong>3. Conflict of Interest & Private Remuneration:</strong><br>
Faculty members are strictly prohibited from conducting private paid tuitions for currently enrolled institutional students, or accepting gratuities from commercial textbook vendors or campus contractors.</p>

<p><strong>4. Digital Communications Decorum:</strong><br>
Staff members must maintain professional boundaries on all electronic platforms. Publishing student likenesses without institutional consent or disparaging institutional integrity on social media is actionable.</p>

<p><strong>AFFIRMATION STATEMENT:</strong><br>
I, <strong>{{employee_name}}</strong> (Staff ID: <strong>{{employee_id}}</strong>), hereby certify that I have received, reviewed, and fully comprehend this Code of Conduct. I pledge my solemn commitment to adhere to every mandate herein.</p>
<p>Signature: ___________________________ &nbsp;&nbsp;&nbsp;&nbsp; Date: _______________</p>
''',
    ),

    // 8. Salary Revision / Promotion Letter
    HRTemplatePreset(
      code: 'TMPL-INCR',
      name: 'Annual Compensation Increment & Promotion Order',
      type: 'HR Forms',
      category: 'Financial Policies',
      description: 'Appraisal increment letter confirming revised CTC compensation, grade promotion, and meritorious performance.',
      variables: [
        'employee_name', 'employee_id', 'designation', 'department',
        'effective_date', 'salary', 'institution_name',
      ],
      contentHtml: '''
<p><strong>Ref:</strong> {{template_code}}/INCR/2026<br>
<strong>Date:</strong> {{effective_date}}</p>

<p><strong>To:</strong><br>
<strong>{{employee_name}}</strong> (Staff ID: {{employee_id}})<br>
Designation: {{designation}}<br>
Department: {{department}}</p>

<p><strong>SUBJECT: ANNUAL PERFORMANCE APPRAISAL & SALARY REVISION</strong></p>

<p>Dear {{employee_name}},</p>

<p>Following the conclusion of the Annual Academic & Performance Appraisal Cycle, the Leadership Council of <strong>{{institution_name}}</strong> is delighted to commend your outstanding instructional dedication, research productivity, and collaborative leadership throughout the preceding academic year.</p>

<p>In recognition of your meritorious contributions, we are pleased to inform you that your Annual Compensation Package has been revised to <strong>{{salary}}</strong>, effective from <strong>{{effective_date}}</strong>.</p>

<p>Additionally, you are confirmed in the elevated institutional grade of <strong>{{designation}}</strong>, with expanded leadership responsibilities in departmental curriculum modernization and faculty mentoring.</p>

<p>We thank you for your steadfast commitment to institutional excellence and look forward to your continued scholarly achievements.</p>

<p>Heartiest congratulations!</p>

<p>Warm regards,</p>
<p><strong>President & Director General</strong><br>
{{institution_name}}</p>
''',
    ),

    // 9. Joining Checklist & Onboarding Form
    HRTemplatePreset(
      code: 'TMPL-CHKL',
      name: 'Employee Joining & Credential Verification Checklist',
      type: 'Joining Checklist',
      category: 'Onboarding',
      description: 'Standard institutional joining verification checklist for documentation, background records, and statutory accounts.',
      variables: [
        'employee_name', 'employee_id', 'designation', 'department',
        'joining_date', 'institution_name',
      ],
      contentHtml: '''
<p><strong>INSTITUTIONAL ONBOARDING & CREDENTIAL VERIFICATION FORM</strong></p>

<p><strong>Employee Name:</strong> {{employee_name}} &nbsp;&nbsp;&nbsp;&nbsp; <strong>Staff ID:</strong> {{employee_id}}<br>
<strong>Department:</strong> {{department}} &nbsp;&nbsp;&nbsp;&nbsp; <strong>Designation:</strong> {{designation}}<br>
<strong>Date of Joining:</strong> {{joining_date}} &nbsp;&nbsp;&nbsp;&nbsp; <strong>Institution:</strong> {{institution_name}}</p>

<hr>
<p><strong>Mandatory Document Submission Audit:</strong></p>
<table border="1" cellpadding="6" cellspacing="0" style="width:100%; border-collapse:collapse; font-size:12px;">
  <tr style="background:#f1f5f9;">
    <th>#</th>
    <th>Document Type</th>
    <th>Verification Status</th>
    <th>Remarks / Reference No.</th>
  </tr>
  <tr><td>1</td><td>Certified Copies of Educational Degrees & Marks Sheets</td><td>[ ] Verified</td><td>Verified against originals</td></tr>
  <tr><td>2</td><td>Previous Employment Relieving & Experience Letters</td><td>[ ] Verified</td><td>Tenure documented</td></tr>
  <tr><td>3</td><td>Government Identity Proof (Aadhaar / Passport / PAN)</td><td>[ ] Verified</td><td>Biometric KYC completed</td></tr>
  <tr><td>4</td><td>Cancelled Bank Cheque for Direct Deposit Payroll</td><td>[ ] Verified</td><td>Account linked</td></tr>
  <tr><td>5</td><td>Police Clearance Certificate & Background Verification</td><td>[ ] Verified</td><td>Clearance received</td></tr>
  <tr><td>6</td><td>Signed NDA & Institutional Code of Conduct Pledge</td><td>[ ] Verified</td><td>On record in HR archive</td></tr>
</table>

<p><strong>HR Officer Certification:</strong><br>
I certify that all required credentials have been verified and archived in accordance with institutional accreditation compliance standards.</p>
<p>HR Officer Signature: _______________________ &nbsp;&nbsp;&nbsp;&nbsp; Date: _______________</p>
''',
    ),
  ];

  static List<HRTemplatePreset> _cachedDbPresets = [];

  /// Asynchronously fetch presets from the database API (/hr/templates/presets).
  /// Caches the results in memory.
  static Future<List<HRTemplatePreset>> fetchPresetsFromDb({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDbPresets.isNotEmpty) {
      return _cachedDbPresets;
    }
    try {
      final api = ApiService();
      final res = await api.get('/hr/templates/presets', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .map((e) => HRTemplatePreset.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isNotEmpty) {
          _cachedDbPresets = list;
          return _cachedDbPresets;
        }
      }
    } catch (_) {}
    return presets;
  }

  static HRTemplatePreset getPresetForType(String type) {
    final cleanType = type.trim().toLowerCase();

    // 1. Check dynamically loaded database presets first
    if (_cachedDbPresets.isNotEmpty) {
      for (final p in _cachedDbPresets) {
        if (p.type.toLowerCase() == cleanType) return p;
      }
      for (final p in _cachedDbPresets) {
        if (cleanType.contains(p.type.toLowerCase()) || p.type.toLowerCase().contains(cleanType)) {
          return p;
        }
      }
      if (cleanType.contains('warn')) {
        final found = _cachedDbPresets.where((p) => p.type.toLowerCase().contains('warn')).toList();
        if (found.isNotEmpty) return found.first;
      }
    }

    // 2. Fallback to baseline default presets
    for (final p in presets) {
      if (p.type.toLowerCase() == cleanType) return p;
    }
    for (final p in presets) {
      if (cleanType.contains(p.type.toLowerCase()) || p.type.toLowerCase().contains(cleanType)) {
        return p;
      }
    }
    // Fallback: Warning letter if warning, else first
    if (cleanType.contains('warn')) {
      return presets.firstWhere((p) => p.type == 'Warning Letter');
    }
    return presets.first;
  }

  static Map<String, String> getSampleDataForType(String type) {
    final cleanType = type.trim().toLowerCase();
    final base = {
      'employee_name': 'Dr. Rajesh Verma',
      'employee_id': 'EMP-2024-042',
      'employee_email': 'rajesh.verma@institution.edu.in',
      'employee_phone': '+91 98765 43210',
      'employee_address': 'Flat 402, Green Avenue Towers, Knowledge Park, City',
      'designation': 'Senior Faculty & Academic Coordinator',
      'department': 'Department of Academics & Sciences',
      'reporting_manager': 'Prof. Alok Mukherjee (Dean of Academics)',
      'work_location': 'Main Campus, North Block',
      'joining_date': '12 July 2021',
      'effective_date': '24 September 2026',
      'relieving_date': '30 September 2026',
      'salary': '₹ 10,20,000 / annum (₹ 85,000 / month)',
      'probation_period': 'Six (6) Months',
      'notice_period': 'Three (3) Months',
      'institution_name': 'Greenfield International Institution',
      'campus_address': 'Plot 14, Institutional Area, Sector 62, NCR Region',
      'authorized_signatory_name': 'Dr. Arindam Sen, Ph.D.',
      'authorized_signatory_title': 'Director of Human Resources & Institutional Governance',
      'hr_contact_email': 'hr@greenfield.edu.in',
    };

    if (cleanType.contains('warn')) {
      base['warning_level'] = 'First Formal Written Warning';
      base['incident_date'] = '18 September 2026';
      base['policy_violated'] = 'Section 4.2 (Attendance & Professional Decorum Policy)';
      base['reason_for_warning'] = 'Repeated unexcused absenteeism and non-submission of student evaluation gradebooks by deadline';
      base['corrective_action_plan'] = 'Immediate adherence to daily biometric schedule and completion of pending logs within 5 working days';
      base['review_period'] = 'Thirty (30) Calendar Days';
      base['template_code'] = 'TMPL-WARN-01';
    } else if (cleanType.contains('offer')) {
      base['template_code'] = 'TMPL-OFFER-01';
    } else if (cleanType.contains('appoint')) {
      base['template_code'] = 'TMPL-APPT-01';
    } else if (cleanType.contains('reliev')) {
      base['template_code'] = 'TMPL-REL-01';
    } else if (cleanType.contains('nda')) {
      base['template_code'] = 'TMPL-NDA-01';
    } else if (cleanType.contains('conduct')) {
      base['template_code'] = 'TMPL-COC-01';
    } else {
      base['template_code'] = 'TMPL-EXP-01';
    }

    return base;
  }

  /// Substitutes all dynamic {{tags}} with realistic context data, keeping HTML intact.
  static String substituteVariables(String templateHtml, String type, [Map<String, String>? customReplacements]) {
    String text = templateHtml;
    final replacements = {...getSampleDataForType(type), ...(customReplacements ?? {})};

    replacements.forEach((key, val) {
      text = text.replaceAll('{{$key}}', val);
      text = text.replaceAll('{$key}', val);
    });
    return text;
  }

  static String renderPreview(String templateHtml, String type, [Map<String, String>? customReplacements]) {
    final text = substituteVariables(templateHtml, type, customReplacements);

    return text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '  • ')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}
