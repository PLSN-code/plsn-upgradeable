from itertools import product

# كلمة ثابتة عندك
known_word = "address"

# قائمة كلمات BIP39 (عليك تنزيل ملفها text عشان تستعمله)
with open("bip39_wordlist.txt", "r") as f:
    wordlist = [w.strip() for w in f.readlines()]

# عدد الكلمات في العبارة
phrase_length = 12

# نجرب نركب كلمات مع كلمة "address" في كل موقع
def generate_phrases():
    for pos in range(phrase_length):
        # باقي المواقع (بدون pos)
        other_positions = phrase_length - 1

        # نختار كلمات من القائمة لباقي المواقع
        # هنا مثال بسيط: نجرب فقط أول 5 كلمات لكل موقع لتجربة سريعة (للتجربة فقط)
        sample_words = wordlist[:5]

        # تركيب الكلمات مع كلمة address في موقع pos
        for combo in product(sample_words, repeat=other_positions):
            phrase = list(combo)
            phrase.insert(pos, known_word)
            yield phrase

if __name__ == "__main__":
    for phrase in generate_phrases():
        print(" ".join(phrase))
        # هنا تقدر تضيف كود للتحقق من صحة العبارة أو توليد العنوان

