import 'dart:math';
import 'package:image/image.dart';

class BinaryProvider {
  String hiddenBinary;
  int hiddenBinaryIndex;
  int hiddenBinaryIndexMax;
  String startString;
  String startBinary;
  int startBinaryIndex;
  int startBinaryIndexMax;
  String endString;
  String endBinary;
  int endBinaryIndex;
  int endBinaryIndexMin;

  BinaryProvider(String startString, String hiddenString, String endString)
      : hiddenBinary = '',
        hiddenBinaryIndex = 0,
        hiddenBinaryIndexMax = 0,
        startString = '',
        startBinary = '',
        startBinaryIndex = 0,
        startBinaryIndexMax = 0,
        endBinary = '',
        endString = '',
        endBinaryIndex = 0,
        endBinaryIndexMin = 0 {
    hiddenBinary = strToBinary(hiddenString);
    hiddenBinaryIndex = 0;
    hiddenBinaryIndexMax = hiddenBinary.length;

    startBinary = strToBinary(startString);
    startBinaryIndex = 0;
    startBinaryIndexMax = startBinary.length;

    endBinary = strToBinary(endString);
    endBinaryIndex = endBinary.length - 1;
    endBinaryIndexMin = 0;
  }

  String strToBinary(String string) {
    return string
        .split('')
        .map((char) => char.codeUnitAt(0).toRadixString(2).padLeft(8, '0'))
        .join();
  }

  int nextBit() {
    int bit;
    if (startBinaryIndex == startBinaryIndexMax) {
      if (hiddenBinaryIndex >= hiddenBinaryIndexMax) {
        hiddenBinaryIndex = 0;
      }
      bit = int.parse(hiddenBinary[hiddenBinaryIndex]);
      hiddenBinaryIndex += 1;
    } else {
      bit = int.parse(startBinary[startBinaryIndex]);
      startBinaryIndex += 1;
    }
    return bit;
  }

  int nextEnd() {
    if (endBinaryIndex == endBinaryIndexMin) {
      // null 대신 9 반환(종료 알림)
      return 9;
    }
    int bit = int.parse(endBinary[endBinaryIndex]);
    endBinaryIndex -= 1;
    return bit;
  }
}

// // compute()용 wrapper
// Future<Image> addHiddenBitWrapper(List<dynamic> args) async {
//   // 토큰을 통해 isolate 초기화
//   BackgroundIsolateBinaryMessenger.ensureInitialized(args[0]);

//   XFile image = args[1];
//   BinaryProvider hiddenBinary = args[2];
//   return addHiddenBit(image, hiddenBinary);
// }

// 이미지에 텍스트 숨기기
Future<Image> addHiddenBit(Image img, BinaryProvider hiddenBinary) async {
  // Image? img = decodeImage(await image.readAsBytes());

  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      Color color = img.getPixel(x, y);
      int r = color.r.toInt();
      int g = color.g.toInt();
      int b = color.b.toInt();

      int diffR = (r - 127).abs();
      int diffG = (g - 127).abs();
      int diffB = (b - 127).abs();

      int maxDiff = [diffR, diffG, diffB].reduce(max);

      int targetColorValue;
      if (maxDiff == diffR) {
        targetColorValue = r;
      } else if (maxDiff == diffG) {
        targetColorValue = g;
      } else {
        targetColorValue = b;
      }

      int addDirection = targetColorValue < 127 ? 1 : -1;

      int bit = hiddenBinary.nextBit();

      if (maxDiff == diffR) {
        if (r % 2 != bit) {
          r += addDirection;
        }
      }
      if (maxDiff == diffG) {
        if (g % 2 != bit) {
          g += addDirection;
        }
      }
      if (maxDiff == diffB) {
        if (b % 2 != bit) {
          b += addDirection;
        }
      }

      img.setPixel(x, y, ColorInt8.rgb(r, g, b));
    }
  }

  for (int y = img.height - 1; y > 0; y--) {
    for (int x = img.width - 1; x > 0; x--) {
      Color color = img.getPixel(x, y);
      int r = color.r.toInt();
      int g = color.g.toInt();
      int b = color.b.toInt();

      int diffR = (r - 127).abs();
      int diffG = (g - 127).abs();
      int diffB = (b - 127).abs();

      int maxDiff = [diffR, diffG, diffB].reduce(max);

      int targetColorValue;
      if (maxDiff == diffR) {
        targetColorValue = r;
      } else if (maxDiff == diffG) {
        targetColorValue = g;
      } else {
        targetColorValue = b;
      }

      int addDirection = targetColorValue < 127 ? 1 : -1;

      int bit = hiddenBinary.nextEnd();

      // 종료 알림 (9일경우 종료로 인식)
      if (bit == 9) {
        break;
      }

      if (maxDiff == diffR) {
        if (r % 2 != bit) {
          r += addDirection;
        }
      }
      if (maxDiff == diffG) {
        if (g % 2 != bit) {
          g += addDirection;
        }
      }
      if (maxDiff == diffB) {
        if (b % 2 != bit) {
          b += addDirection;
        }
      }
      img.setPixel(x, y, ColorInt8.rgb(r, g, b));
    }

    if (hiddenBinary.nextEnd() > 1) {
      break;
    }
  }

  return img;
}
