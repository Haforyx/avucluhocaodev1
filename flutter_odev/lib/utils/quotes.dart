/// Ana sayfadaki "Günün sözü" kartı için kısa sözler.
const _quotes = <(String, String)>[
  ('Hayatta en hakiki mürşit ilimdir.', 'Mustafa Kemal Atatürk'),
  ('Bir işe başlamak, onu bitirmenin yarısıdır.', 'Platon'),
  ('Başarı, her gün tekrarlanan küçük çabaların toplamıdır.', 'Robert Collier'),
  ('Öğrenmek hiçbir zaman zihni yormaz.', 'Leonardo da Vinci'),
  ('Ne kadar bilirsen bil, söylediklerin karşındakinin anlayabildiği kadardır.', 'Mevlânâ'),
  ('Bilgi güçtür.', 'Francis Bacon'),
  ('Disiplin, hedefler ile başarı arasındaki köprüdür.', 'Jim Rohn'),
  ('Yapabileceğinin en iyisini, sahip olduklarınla, bulunduğun yerde yap.', 'Theodore Roosevelt'),
  ('İlim ilim bilmektir, ilim kendin bilmektir.', 'Yunus Emre'),
  ('Uzun bir yolculuk tek bir adımla başlar.', 'Lao Tzu'),
  ('Dâhilik yüzde bir ilham, yüzde doksan dokuz terdir.', 'Thomas Edison'),
  ('Bugün yapabileceğini yarına bırakma.', 'Benjamin Franklin'),
  ('Eğitim, dünyayı değiştirmek için kullanabileceğin en güçlü silahtır.', 'Nelson Mandela'),
  ('Mükemmel olmak için değil, dünden daha iyi olmak için çalış.', 'Anonim'),
];

/// Her gün değişen, gün boyunca aynı kalan söz.
(String, String) quoteOfTheDay(DateTime now) {
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  return _quotes[(dayOfYear + now.year) % _quotes.length];
}
