import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

const Terms = () => {
  return (
    <div className='min-h-screen flex flex-col'>
      <Navbar />

      <main className='grow bg-white'>
        <div className='max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-16'>
          <div className='p-4 md:p-8 lg:p-12'>
            <h1 className='text-xl md:text-3xl font-bold text-gray-900 mb-2 text-center animate-slide-up'>
              Terms & Conditions
            </h1>
            <p className='text-center text-xs md:text-sm text-gray-600 mb-8 md:mb-12 animate-slide-up animation-delay-200'>
              Please read these terms carefully
            </p>

            <div className='max-w-none space-y-6 md:space-y-8 text-gray-700 animate-fade-in animation-delay-400'>
              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Introduction</h2>
                <p className='text-sm leading-relaxed'>
                  Welcome to Maxmiize Sports Analysis Platform. These Terms and Conditions govern your use of our
                  professional-grade macOS desktop application for basketball video analysis. Maxmiize enables coaches,
                  analysts, and teams to capture, analyze, and present game footage with an intuitive interface designed
                  specifically for basketball workflows. By accessing or using our software, you agree to be bound by
                  these terms.
                </p>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Software Description</h2>
                <p className='text-sm leading-relaxed'>
                  Maxmiize is a professional-grade macOS desktop application that provides:
                </p>
                <ul className='list-disc pl-6 space-y-2 mt-4 text-sm'>
                  <li>
                    <strong>Multi-Angle Video Capture:</strong> Record from 4+ simultaneous cameras via HDMI/USB input
                    with frame-accurate playback and synchronization
                  </li>
                  <li>
                    <strong>Basketball Tagging System:</strong> Pre-built basketball event templates with customizable
                    hotkey configuration for real-time and post-game tagging
                  </li>
                  <li>
                    <strong>Annotation Tools:</strong> Professional drawing tools including lines, arrows, shapes, court
                    overlay templates, and telestration capabilities
                  </li>
                  <li>
                    <strong>Playlist Management:</strong> Create and organize playlists from tagged possessions with
                    advanced filtering and export capabilities
                  </li>
                  <li>
                    <strong>Statistical Analysis:</strong> Automatic statistics generation, shot charts with heat maps,
                    and player performance tracking
                  </li>
                  <li>
                    <strong>Presentation Builder:</strong> Film room presentation mode with split-screen layouts and
                    screen-record features
                  </li>
                </ul>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Software License</h2>
                <p className='text-sm leading-relaxed'>
                  MAXMIIZE SPORTS GROUP LLC grants you a non-transferable, time-limited license to use the Sports
                  Analysis Platform. The software operates offline by default, with optional cloud-based features
                  requiring license validation.
                </p>
                <ul className='list-disc pl-6 space-y-2 mt-4 text-sm'>
                  <li>
                    <strong>License Tiers:</strong> Available in MVP (Pro Coach Essentials), PRO (Team Workflow &
                    Advanced Features), and ELITE (AI & Cloud Integration) tiers
                  </li>
                  <li>
                    <strong>Duration:</strong> License duration may be configured as 6 or 12 months
                  </li>
                  <li>
                    <strong>Renewal:</strong> Renewal is handled according to our renewal policy
                  </li>
                  <li>License keys and activation codes must not be shared beyond the agreed scope</li>
                  <li>
                    Upon expiration, cloud-enabled features will be disabled while offline functionality may continue
                    per license terms
                  </li>
                  <li>
                    <strong>System Requirements:</strong> Requires macOS 12.0 (Monterey) or later, Apple Silicon (M1+)
                    or Intel i5 (8th gen+), 8GB RAM minimum
                  </li>
                </ul>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Permitted Use</h2>
                <p className='text-sm leading-relaxed'>
                  The software is designed for professional basketball coaches, analysts, and teams for video analysis,
                  tagging, annotation, and presentation purposes specifically for game breakdown, player development,
                  and opponent scouting. You agree to:
                </p>
                <ul className='list-disc pl-6 space-y-2 mt-4 text-sm'>
                  <li>Use the software in compliance with all applicable laws and regulations</li>
                  <li>Use the software solely for legitimate basketball coaching and analysis purposes</li>
                  <li>Not reverse engineer, decompile, or attempt to extract source code</li>
                  <li>Not distribute, sublicense, or transfer the software to third parties</li>
                  <li>Maintain the confidentiality of your license credentials</li>
                  <li>Respect copyright and privacy rights of video content you import and analyze</li>
                  <li>Not use the software for any illegal, harmful, or unauthorized purposes</li>
                </ul>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Intellectual Property</h2>
                <p className='text-sm leading-relaxed'>
                  All software, documentation, and materials provided are the intellectual property of MAXMIIZE SPORTS
                  GROUP LLC. You acknowledge that:
                </p>
                <ul className='list-disc pl-6 space-y-2 mt-4 text-sm'>
                  <li>We retain all rights, title, and interest in the software and related materials</li>
                  <li>Your license does not transfer any ownership rights</li>
                  <li>Content you create using the software (videos, tags, annotations) remains your property</li>
                </ul>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Warranty and Support</h2>
                <p className='text-sm leading-relaxed'>
                  We provide a 12-month warranty period following delivery, during which we will:
                </p>
                <ul className='list-disc pl-6 space-y-2 mt-4 text-sm'>
                  <li>Correct reproducible defects or malfunctions</li>
                  <li>Optimize performance where reasonably necessary</li>
                  <li>Maintain compatibility with supported operating system updates released during that period</li>
                </ul>
                <p className='mt-4 text-sm leading-relaxed'>
                  Post-warranty maintenance and support are available under separate agreement.
                </p>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>
                  Limitation of Liability
                </h2>
                <p className='text-sm leading-relaxed'>
                  To the maximum extent permitted by law, MAXMIIZE SPORTS GROUP LLC shall not be liable for any
                  indirect, incidental, or consequential damages arising from your use of the software. Our total
                  liability shall not exceed the fees paid for the license.
                </p>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>
                  Data Storage and Privacy
                </h2>
                <p className='text-sm leading-relaxed'>
                  The software operates primarily offline with local SQLite database storage. Any data transmitted for
                  cloud validation or optional features will be handled in accordance with our Privacy Policy. You are
                  responsible for:
                </p>
                <ul className='list-disc pl-6 space-y-2 mt-4 text-sm'>
                  <li>
                    <strong>Data Backup:</strong> Regularly backing up your project files, video content, tags,
                    annotations, and database
                  </li>
                  <li>
                    <strong>Data Security:</strong> Securing your local storage, credentials, and license keys
                  </li>
                  <li>
                    <strong>Compliance:</strong> Complying with applicable data protection laws (GDPR, CCPA, etc.) for
                    video content you process
                  </li>
                  <li>
                    <strong>Video Content Rights:</strong> Ensuring you have proper rights and permissions for all video
                    content imported into the software
                  </li>
                  <li>
                    <strong>Player Privacy:</strong> Respecting athlete privacy rights and obtaining necessary consents
                    for video analysis
                  </li>
                </ul>
                <p className='text-sm leading-relaxed mt-4'>
                  The software stores data locally in SQLite format with 23 tables and 45 performance indexes. Cloud
                  features, when enabled, may sync limited metadata for license validation and optional collaboration
                  features.
                </p>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Termination</h2>
                <p className='text-sm leading-relaxed'>
                  This agreement may be terminated if you breach these terms. Upon termination:
                </p>
                <ul className='list-disc pl-6 space-y-2 mt-4 text-sm'>
                  <li>Your license to use the software is revoked</li>
                  <li>You must cease all use of the software</li>
                  <li>You may retain your project data created during the license period</li>
                </ul>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Governing Law</h2>
                <p className='text-sm leading-relaxed'>
                  These Terms and Conditions shall be governed by and construed in accordance with the laws of the State
                  of Delaware, United States, without regard to its conflict of law principles.
                </p>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Performance Standards</h2>
                <p className='text-sm leading-relaxed'>
                  Maxmiize is designed to meet the following performance standards:
                </p>
                <ul className='list-disc pl-6 space-y-2 mt-4 text-sm'>
                  <li>Launch Time: Less than 2 seconds</li>
                  <li>Video Seek Latency: Less than 200ms (MVP), less than 100ms (PRO)</li>
                  <li>Frame Rate: 60fps playback</li>
                  <li>Multi-Angle Support: 4x 1080p@60fps simultaneous playback</li>
                  <li>4K Support: 2x 4K@30fps (PRO tier)</li>
                  <li>Auto-Save: Automatic project saving every 30 seconds</li>
                </ul>
                <p className='text-sm leading-relaxed mt-4'>
                  Performance may vary based on your hardware configuration and video file formats. We recommend using
                  Apple Silicon (M1 Pro/Max/Ultra or M2+) with 16GB RAM for optimal 4K performance.
                </p>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>
                  Supported File Formats
                </h2>
                <p className='text-sm leading-relaxed'>
                  The software supports import and export of the following video formats:
                </p>
                <ul className='list-disc pl-6 space-y-2 mt-4 text-sm'>
                  <li>
                    <strong>Import:</strong> MP4, MOV, H.264, H.265, ProRes formats
                  </li>
                  <li>
                    <strong>Export:</strong> MP4 video with compiled playlists and annotations
                  </li>
                  <li>
                    <strong>Data Export:</strong> CSV/Excel format for statistics and analytics
                  </li>
                  <li>
                    <strong>Compatibility:</strong> Sportscode and Catapult import/export support
                  </li>
                </ul>
              </section>

              <section>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Changes to Terms</h2>
                <p className='text-sm leading-relaxed'>
                  We reserve the right to modify these terms at any time. Material changes will be communicated via
                  email or in-app notification. Continued use of the software after changes constitutes acceptance of
                  the modified terms.
                </p>
              </section>

              <section className='mt-12 pt-8 border-t border-gray-200'>
                <h2 className='text-base md:text-lg font-semibold text-gray-900 mb-3 md:mb-4'>Contact Information</h2>
                <p className='text-sm leading-relaxed'>
                  For questions about these Terms and Conditions, please contact:
                  <br />
                  <strong>MAXMIIZE SPORTS GROUP LLC</strong>
                  <br />
                  800 N King St, Suite 304-2397
                  <br />
                  Wilmington, Delaware, 19801
                  <br />
                  United States
                  <br />
                  <a href='mailto:info@maxmiize.com' className='text-[#2979ff] hover:underline'>
                    info@maxmiize.com
                  </a>
                </p>
                <p className='mt-6 text-sm text-gray-500'>Last Updated: January 2026</p>
              </section>
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default Terms;
