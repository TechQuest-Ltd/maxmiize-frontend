const Footer = () => {
  const currentYear = new Date().getFullYear();

  return (
    <footer className='bg-gray-100 text-slate-700 py-6 mt-auto animate-fade-in'>
      <div className='max-w-7xl mx-auto px-4 sm:px-6 lg:px-8'>
        <div className='text-center text-xs md:text-sm text-slate-600 transition-colors duration-200 hover:text-slate-900'>
          © {currentYear} Maxmiize Sports Group LLC. All Rights Reserved.
        </div>
      </div>
    </footer>
  );
};

export default Footer;
