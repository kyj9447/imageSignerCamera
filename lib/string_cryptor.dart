import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:asn1lib/asn1lib.dart';

import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart';

Future<String> stringCryptor(String str) async {
  // 공개키 문자열 read
  String publicKeyContent =
      await rootBundle.loadString('assets/public_key.pem');

  // 불필요한 문자열 제거
  publicKeyContent =
      publicKeyContent.replaceAll('-----BEGIN PUBLIC KEY-----', '');
  publicKeyContent =
      publicKeyContent.replaceAll('-----END PUBLIC KEY-----', '');
  publicKeyContent =
      publicKeyContent.replaceAll(RegExp(r'[^A-Za-z0-9\+\/=]'), '');
  publicKeyContent = publicKeyContent.replaceAll(' ', '');

  // base64 디코딩
  var publicKeyDER = base64Decode(publicKeyContent);
  var asn1Parser = ASN1Parser(publicKeyDER);
  var topLevelSequence = asn1Parser.nextObject() as ASN1Sequence;
  var publicKeyBitString = topLevelSequence.elements[1];

  var publicKeyAsn = ASN1Parser(publicKeyBitString.contentBytes());
  var publicKeySeq = publicKeyAsn.nextObject() as ASN1Sequence;

  var modulus = publicKeySeq.elements[0] as ASN1Integer;
  var exponent = publicKeySeq.elements[1] as ASN1Integer;

  var rsaPublicKey =
      RSAPublicKey(modulus.valueAsBigInteger, exponent.valueAsBigInteger);

  // // 암호화
  // var encrypter = Encrypter(RSA(publicKey: rsaPublicKey));
  // var encrypted = encrypter.encrypt(str);

  // return encrypted.base64;

  // 암호화
  var secureRandom = FortunaRandom();
  secureRandom.seed(KeyParameter(Uint8List.fromList(
      DateTime.now().millisecondsSinceEpoch.toRadixString(16).codeUnits)));
  var params = RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 12);
  var keyGenerator = RSAKeyGenerator()
    ..init(ParametersWithRandom(params, secureRandom));
  var pair = keyGenerator.generateKeyPair();
  var myPublic = pair.publicKey as RSAPublicKey;

  var cipher = PKCS1Encoding(RSAEngine())
    ..init(true, PublicKeyParameter<RSAPublicKey>(myPublic)); // true=encrypt

  var out = cipher.process(utf8.encode(str));

  return base64Encode(out);
}
