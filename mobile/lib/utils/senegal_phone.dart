String? normalizeSenegalPhone(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('221') && digits.length == 12) {
    digits = digits.substring(3);
  }
  if (digits.length == 10 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length != 9) return null;
  return '+221$digits';
}
