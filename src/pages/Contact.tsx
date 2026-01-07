import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import { Mail, MapPin, Phone } from 'lucide-react';

const Contact = () => {
  return (
    <div className='min-h-screen flex flex-col'>
      <Navbar />

      <main className='grow bg-gray-50'>
        <div className='max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-16'>
          <div className='text-center mb-12'>
            <h1 className='text-4xl font-bold text-gray-900 mb-4'>Contact Us</h1>
            <p className='text-lg text-gray-600'>Get in touch with our team. We'd love to hear from you.</p>
          </div>

          <div className='bg-white rounded-lg shadow-sm p-8 md:p-12'>
            <div className='space-y-8'>
              <div className='flex items-start space-x-4'>
                <div className='w-12 h-12 bg-[#2979ff] rounded-lg flex items-center justify-center flex-shrink-0'>
                  <MapPin className='w-6 h-6 text-white' />
                </div>
                <div>
                  <h3 className='text-lg font-bold text-gray-900 mb-2'>Address</h3>
                  <p className='text-gray-600'>
                    MAXMIIZE SPORTS GROUP LLC
                    <br />
                    800 N King St, Suite 304-2397
                    <br />
                    Wilmington, Delaware, 19801
                    <br />
                    United States
                  </p>
                </div>
              </div>

              <div className='flex items-start space-x-4'>
                <div className='w-12 h-12 bg-[#2979ff] rounded-lg flex items-center justify-center flex-shrink-0'>
                  <Mail className='w-6 h-6 text-white' />
                </div>
                <div>
                  <h3 className='text-lg font-bold text-gray-900 mb-2'>Email</h3>
                  <a href='mailto:info@maxmiize.com' className='text-[#2979ff] hover:underline text-lg'>
                    info@maxmiize.com
                  </a>
                </div>
              </div>

              <div className='flex items-start space-x-4'>
                <div className='w-12 h-12 bg-[#2979ff] rounded-lg flex items-center justify-center flex-shrink-0'>
                  <Phone className='w-6 h-6 text-white' />
                </div>
                <div>
                  <h3 className='text-lg font-bold text-gray-900 mb-2'>Phone</h3>
                  <p className='text-gray-600 text-lg'>Available upon request</p>
                </div>
              </div>
            </div>

            <div className='mt-12 pt-8 border-t border-gray-200'>
              <p className='text-center text-gray-600'>
                For inquiries about our sports video analysis platform, licensing, or support, please reach out via
                email and our team will respond within 1-2 business days.
              </p>
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default Contact;
