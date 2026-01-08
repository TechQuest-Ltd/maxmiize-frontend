import { useState } from 'react';
import { cn } from '@/lib/utils';

interface BlurImageProps extends React.ImgHTMLAttributes<HTMLImageElement> {
  src: string;
  alt: string;
  className?: string;
}

const BlurImage = ({ src, alt, className, ...props }: BlurImageProps) => {
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);

  return (
    <div className={cn('relative overflow-hidden', className)}>
      {isLoading && <div className='absolute inset-0 bg-gray-200 animate-pulse' />}
      {hasError ? (
        <div className='absolute inset-0 bg-gray-300 flex items-center justify-center'>
          <span className='text-gray-500 text-sm'>Failed to load image</span>
        </div>
      ) : (
        <img
          src={src}
          alt={alt}
          className={cn('transition-opacity duration-300', isLoading ? 'opacity-0' : 'opacity-100', className)}
          onLoad={() => setIsLoading(false)}
          onError={() => {
            setIsLoading(false);
            setHasError(true);
          }}
          {...props}
        />
      )}
    </div>
  );
};

export default BlurImage;
