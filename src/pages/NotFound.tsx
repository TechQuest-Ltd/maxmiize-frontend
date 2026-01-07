import { Button } from '@/components/ui/button';
import { useNavigate } from 'react-router-dom';
import { FileQuestion } from 'lucide-react';

const NotFound = () => {
  const navigate = useNavigate();

  const handleBack = () => {
    navigate(-1);
  };

  return (
    <div className='flex flex-col items-center justify-center min-h-[60vh] px-4'>
      <div className='text-center'>
        <FileQuestion className='w-24 h-24 mx-auto text-gray-400 mb-6' />
        <h1 className='text-6xl font-[sofia-bold] text-gray-900 mb-4'>404</h1>
        <p className='text-xl text-gray-600 mb-8'>Sorry, the page you are looking for was not found.</p>
        <Button onClick={handleBack} className='bg-primary hover:bg-primary/90'>
          Go Back
        </Button>
      </div>
    </div>
  );
};

export default NotFound;
