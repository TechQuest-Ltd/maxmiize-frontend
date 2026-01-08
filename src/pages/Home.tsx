import { Link } from 'react-router-dom';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import BlurImage from '@/components/BlurImage';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import aprImage from '@/assets/apr.jpg';
import systemImage from '@/assets/system.png';

const Home = () => {
  const features = {
    video: [
      {
        title: 'Multi-Angle Capture',
        description: 'Record 4+ cameras simultaneously via HDMI/USB with frame-perfect sync',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z'
          />
        ),
      },
      {
        title: 'Frame-Accurate Playback',
        description: 'Variable speed control (0.25x - 6x) with instant seek',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z'
          />
        ),
      },
      {
        title: 'Multi-Format Support',
        description: 'Import MP4, MOV, H.264, H.265, ProRes formats seamlessly',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z'
          />
        ),
      },
    ],
    tagging: [
      {
        title: 'Basketball Templates',
        description: 'Pre-built event templates with customizable hotkeys',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z'
          />
        ),
      },
      {
        title: 'Real-Time Tagging',
        description: 'Tag events during live games or post-game analysis',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z'
          />
        ),
      },
      {
        title: 'Player Tracking',
        description: 'Assign tags to specific players for detailed performance analysis',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z'
          />
        ),
      },
    ],
    annotation: [
      {
        title: 'Drawing Tools',
        description: 'Lines, arrows, shapes, and freehand telestration',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z'
          />
        ),
      },
      {
        title: 'Court Overlay Templates',
        description: 'Half-court and full-court overlays for play breakdown',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z'
          />
        ),
      },
      {
        title: '50-Step Undo/Redo',
        description: 'Comprehensive history for perfect annotation refinement',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6'
          />
        ),
      },
    ],
    playlists: [
      {
        title: 'Smart Filtering',
        description: 'Filter by player, event type, outcome, quarter, and more',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z'
          />
        ),
      },
      {
        title: 'Drag & Drop Organization',
        description: 'Intuitive clip management for custom game breakdowns',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4'
          />
        ),
      },
      {
        title: 'Export to MP4',
        description: 'Create shareable film session videos with compiled playlists',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4'
          />
        ),
      },
    ],
    analytics: [
      {
        title: 'Shot Charts',
        description: 'Auto-generate heat maps and shooting statistics',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z'
          />
        ),
      },
      {
        title: 'Player Performance',
        description: 'Track individual metrics and development over time',
        icon: <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M13 7h8m0 0v8m0-8l-8 8-4-4-6 6' />,
      },
      {
        title: 'CSV/Excel Export',
        description: 'Export detailed statistics for further analysis',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z'
          />
        ),
      },
    ],
    presentation: [
      {
        title: 'Film Room Mode',
        description: 'Professional presentation layouts for team sessions',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z'
          />
        ),
      },
      {
        title: 'Split-Screen Layouts',
        description: 'Compare angles and plays with picture-in-picture',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2'
          />
        ),
      },
      {
        title: 'Screen Record + Voice',
        description: 'Capture presentations with live voice-over commentary',
        icon: (
          <path
            strokeLinecap='round'
            strokeLinejoin='round'
            strokeWidth={2}
            d='M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z'
          />
        ),
      },
    ],
  };

  const tabs = [
    { id: 'video', label: 'Video Management' },
    { id: 'tagging', label: 'Tagging System' },
    { id: 'annotation', label: 'Annotation Tools' },
    { id: 'playlists', label: 'Playlists' },
    { id: 'analytics', label: 'Analytics' },
    { id: 'presentation', label: 'Presentation' },
  ];

  return (
    <div className='min-h-screen flex flex-col bg-white'>
      <Navbar />

      <main className='grow'>
        {/* Hero Section */}
        <section className='relative pt-12 pb-16 px-6 overflow-hidden'>
          <div className='absolute inset-0 bg-linear-to-b from-gray-50 to-white'></div>

          <div className='relative max-w-6xl mx-auto'>
            <div className='text-center mb-8 animate-fade-in'>
              <h1 className='text-2xl md:text-4xl font-bold text-slate-900 mb-4 leading-tight animate-slide-up'>
                Powerful Video Analysis
                <br />
                <span className='text-[#2979ff]'>Built for Basketball Coaches</span>
              </h1>
              <p className='text-xs md:text-sm text-slate-600 mb-6 max-w-2xl mx-auto animate-slide-up animation-delay-200'>
                Streamline game breakdown, player development, and opponent scouting with frame-accurate playback and
                intuitive tagging tools.
              </p>
              <a
                href='https://wa.me/14044528091?text=Hi%2C%20I%27m%20interested%20in%20Maxmiize%20for%20early%20access'
                target='_blank'
                rel='noopener noreferrer'
                className='inline-block px-5 md:px-6 py-2 md:py-2.5 bg-[#2979ff] text-white font-medium text-xs md:text-sm rounded-md hover:bg-[#1e5bb8] hover:scale-102 transition-all duration-500 animate-slide-up animation-delay-400'
              >
                Contact Us for Early Access
              </a>
            </div>

            {/* Product Images */}
            <div className='max-w-5xl mx-auto mt-10'>
              {/* Desktop View */}
              <div className='hidden md:block px-4 md:px-0'>
                <div className='relative flex justify-center min-h-112.5'>
                  {/* Main Image - APR (Bigger) */}
                  <div className='relative z-10 w-[70%]'>
                    <BlurImage
                      src={aprImage}
                      alt='Basketball Video Tagging'
                      className='w-full rounded-lg border border-gray-300'
                    />
                  </div>

                  {/* Overlapping Image - System (Smaller, Extended to right) */}
                  <div className='absolute top-12 -right-8 lg:-right-16 w-[48%] z-20'>
                    <BlurImage
                      src={systemImage}
                      alt='Multi-Angle Video Playback'
                      className='w-full rounded-lg border border-gray-300'
                    />
                  </div>
                </div>
              </div>

              {/* Mobile View */}
              <div className='block md:hidden px-4'>
                <div className='relative'>
                  <div className='w-full'>
                    <BlurImage
                      src={aprImage}
                      alt='Basketball Video Tagging'
                      className='w-full rounded-lg border border-gray-300'
                    />
                  </div>
                  <div className='absolute -bottom-20 right-4 w-[80%] z-10'>
                    <BlurImage
                      src={systemImage}
                      alt='Multi-Angle Video Playback'
                      className='w-full rounded-lg border border-gray-300'
                    />
                  </div>
                </div>
                {/* Spacer to prevent overlap with next section */}
                <div className='h-24'></div>
              </div>
            </div>
          </div>
        </section>

        {/* Features Section with Tabs */}
        <section className='py-6 md:py-16 bg-[#00aded]/10'>
          <div className='max-w-6xl mx-auto px-4 md:px-6'>
            <div className='text-center mb-4 md:mb-12 animate-fade-in'>
              <h2 className='text-xl md:text-2xl font-bold text-slate-900 mb-1 md:mb-2 animate-slide-up'>
                Complete Basketball Workflow
              </h2>
              <p className='text-xs md:text-sm text-slate-600 animate-slide-up animation-delay-200'>
                From live capture to film room presentation
              </p>
            </div>

            <Tabs defaultValue='video' className='w-full'>
              {/* Tab Navigation */}
              <div className='mb-4 md:mb-10'>
                <div className='overflow-x-auto md:overflow-visible px-4 md:px-0 -mx-4 md:mx-0'>
                  <div className='flex justify-start md:justify-center min-w-min px-4 md:px-0'>
                    <TabsList className='bg-white p-1 rounded-lg shadow-sm border border-gray-200 inline-flex gap-1'>
                      {tabs.map(tab => (
                        <TabsTrigger
                          key={tab.id}
                          value={tab.id}
                          className='px-2.5 md:px-5 py-1.5 md:py-2.5 text-xs md:text-sm font-medium data-[state=active]:bg-[#2979ff] data-[state=active]:text-white data-[state=active]:shadow-md whitespace-nowrap'
                        >
                          {tab.label}
                        </TabsTrigger>
                      ))}
                    </TabsList>
                  </div>
                </div>
              </div>

              {/* Tab Content */}
              {tabs.map(tab => (
                <TabsContent key={tab.id} value={tab.id} className='mt-0'>
                  <div className='grid grid-cols-1 md:grid-cols-3 gap-3 md:gap-6'>
                    {features[tab.id as keyof typeof features].map((feature, index) => (
                      <div
                        key={index}
                        className='bg-white p-3 md:p-6 rounded-lg border border-gray-200 hover:border-[#2979ff] transition-colors duration-200'
                      >
                        <div className='w-7 h-7 md:w-9 md:h-9 bg-[#2979ff] rounded-lg flex items-center justify-center mb-2 md:mb-3'>
                          <svg
                            className='w-3.5 h-3.5 md:w-4 md:h-4 text-white'
                            fill='none'
                            stroke='currentColor'
                            viewBox='0 0 24 24'
                          >
                            {feature.icon}
                          </svg>
                        </div>
                        <h3 className='text-sm md:text-base font-bold text-slate-900 mb-1 md:mb-2'>{feature.title}</h3>
                        <p className='text-xs md:text-xs text-slate-600'>{feature.description}</p>
                      </div>
                    ))}
                  </div>
                </TabsContent>
              ))}
            </Tabs>
          </div>
        </section>

        {/* CTA Section */}
        <section className='py-8 md:py-16 bg-white'>
          <div className='max-w-4xl mx-auto px-4 md:px-6'>
            <div className='bg-[#2979ff] rounded-2xl p-6 md:p-12 text-center animate-fade-in hover:shadow-2xl transition-shadow duration-300'>
              <h2 className='text-xl md:text-2xl font-bold text-white mb-2 md:mb-3 animate-slide-up'>
                Ready to Get Started?
              </h2>
              <p className='text-xs md:text-sm text-white/90 mb-6 md:mb-8 animate-slide-up animation-delay-200'>
                Join basketball coaches using Maxmiize for video analysis
              </p>
              <div className='flex flex-col sm:flex-row gap-3 md:gap-4 justify-center animate-slide-up animation-delay-400'>
                <a
                  href='https://wa.me/14044528091?text=Hi%2C%20I%27m%20interested%20in%20Maxmiize%20for%20early%20access'
                  target='_blank'
                  rel='noopener noreferrer'
                  className='px-5 md:px-6 py-2 md:py-2.5 bg-white text-[#2979ff] font-medium text-xs md:text-sm rounded-md hover:bg-gray-100 hover:scale-102 transition-all duration-500'
                >
                  Get Started
                </a>
                <Link
                  to='/terms'
                  className='px-5 md:px-6 py-2 md:py-2.5 bg-white/10 text-white font-medium text-xs md:text-sm rounded-md hover:bg-white/20 hover:scale-102 transition-all duration-500 border border-white/20'
                >
                  View Terms
                </Link>
              </div>
            </div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
};

export default Home;
