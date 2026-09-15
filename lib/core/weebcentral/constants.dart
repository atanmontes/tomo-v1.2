const String weebCentralBaseUrl = 'https://weebcentral.com';

const String weebCentralUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/130.0.0.0 Safari/537.36';

const Map<String, String> weebCentralHeaders = {
  'User-Agent': weebCentralUserAgent,
  'Accept':
      'text/html,application/xhtml+xml,application/xml;q=0.9,'
      'image/avif,image/webp,image/apng,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.9',
  'Referer': '$weebCentralBaseUrl/',
};

const Map<String, String> weebCentralImageHeaders = {
  'User-Agent': weebCentralUserAgent,
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  'Referer': '$weebCentralBaseUrl/',
};
