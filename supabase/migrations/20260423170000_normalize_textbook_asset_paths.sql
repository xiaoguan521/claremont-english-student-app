update public.materials
set
  pdf_path = replace(
    replace(pdf_path, 'asset:assets/textbook/', 'asset:assets/textbooks/'),
    'assets/textbook/',
    'assets/textbooks/'
  ),
  cover_image_path = replace(
    replace(cover_image_path, 'asset:assets/textbook/', 'asset:assets/textbooks/'),
    'assets/textbook/',
    'assets/textbooks/'
  ),
  updated_at = timezone('utc', now())
where pdf_path like '%assets/textbook/%'
   or cover_image_path like '%assets/textbook/%';

update public.material_pages
set
  image_path = replace(
    replace(image_path, 'asset:assets/textbook/', 'asset:assets/textbooks/'),
    'assets/textbook/',
    'assets/textbooks/'
  ),
  thumbnail_path = replace(
    replace(thumbnail_path, 'asset:assets/textbook/', 'asset:assets/textbooks/'),
    'assets/textbook/',
    'assets/textbooks/'
  ),
  updated_at = timezone('utc', now())
where image_path like '%assets/textbook/%'
   or thumbnail_path like '%assets/textbook/%';

update public.assignment_items
set
  reference_audio_path = replace(
    replace(reference_audio_path, 'asset:assets/textbook/', 'asset:assets/textbooks/'),
    'assets/textbook/',
    'assets/textbooks/'
  )
where reference_audio_path like '%assets/textbook/%';

update public.material_region_assets
set
  storage_path = replace(
    replace(storage_path, 'asset:assets/textbook/', 'asset:assets/textbooks/'),
    'assets/textbook/',
    'assets/textbooks/'
  ),
  poster_path = replace(
    replace(poster_path, 'asset:assets/textbook/', 'asset:assets/textbooks/'),
    'assets/textbook/',
    'assets/textbooks/'
  ),
  updated_at = timezone('utc', now())
where storage_bucket = 'asset'
  and (
    storage_path like '%assets/textbook/%'
    or poster_path like '%assets/textbook/%'
  );
