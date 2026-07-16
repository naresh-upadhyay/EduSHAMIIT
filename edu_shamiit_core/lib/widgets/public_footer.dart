import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart'; // For AppConfig

class PublicFooter extends StatelessWidget {
  final bool showWideFooter;
  final String name;
  final Function(String section)? onScrollToSection;

  const PublicFooter({
    super.key,
    required this.showWideFooter,
    required this.name,
    this.onScrollToSection,
  });

  Future<void> _launchURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  IconData _getSocialIconData(String platform) {
    switch (platform.toLowerCase().trim()) {
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'twitter':
      case 'x':
        return Icons.close;
      case 'email':
      case 'mail':
        return Icons.alternate_email;
      case 'youtube':
      case 'play':
        return Icons.play_circle_filled;
      case 'linkedin':
        return Icons.business;
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Logo & Column 1
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
                      AppConfig.footerDesc,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: Colors.white60,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: AppConfig.footerSocialLinks.map((social) {
                        return InkWell(
                          onTap: () => _launchURL(social.url),
                          child: _buildSocialIcon(_getSocialIconData(social.platform)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              if (showWideFooter) ...[
                const SizedBox(width: 48),
                Expanded(
                  flex: 2,
                  child: _buildFooterColumn(context, 'Quick Links', AppConfig.footerQuickLinks),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 2,
                  child: _buildFooterColumn(context, 'Modules', AppConfig.footerModules),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 2,
                  child: _buildFooterColumn(context, 'Support', AppConfig.footerSupport),
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
                  child: _buildFooterColumn(context, 'Quick Links', AppConfig.footerQuickLinks),
                ),
                SizedBox(
                  width: 220,
                  child: _buildFooterColumn(context, 'Modules', AppConfig.footerModules),
                ),
                SizedBox(
                  width: 180,
                  child: _buildFooterColumn(context, 'Support', AppConfig.footerSupport),
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
                AppConfig.footerCopyright.replaceAll('\$name', name),
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: Colors.white38,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.white54, size: 16),
                onPressed: () {
                  if (onScrollToSection != null) {
                    onScrollToSection!('Home');
                  } else {
                    context.go('/');
                  }
                },
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
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  Widget _buildFooterColumn(BuildContext context, String title, List<FooterLink> items) {
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
                  final url = item.url.trim();
                  if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('mailto:')) {
                    _launchURL(url);
                  } else {
                    if (url == '/' && onScrollToSection != null) {
                      onScrollToSection!('Home');
                    } else if (url == '/#features' && onScrollToSection != null) {
                      onScrollToSection!('Features');
                    } else if (url == '/#modules' && onScrollToSection != null) {
                      onScrollToSection!('Modules');
                    } else if (url == '/#pricing' && onScrollToSection != null) {
                      onScrollToSection!('Pricing');
                    } else if (url == '/#about' && onScrollToSection != null) {
                      onScrollToSection!('About Us');
                    } else {
                      context.go(url);
                    }
                  }
                },
                child: Text(
                  item.label,
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
