const Jimp = require('jimp');
module.exports = { validateImage };

// binary -> 문자열 변환
function binaryToString(binaryCode) {
    let string = "";
    for (let i = 0; i < binaryCode.length; i += 8) {
        let byte = binaryCode.substring(i, i + 8);
        let decimal = parseInt(byte, 2);
        let character = String.fromCharCode(decimal);
        string += character;
    }
    return string;
}

// 이미지에 숨겨진 비트 추출
async function readHiddenBit(imagePath) {
    let hiddenBinary = "";

    const image = await Jimp.read(imagePath);
    const width = image.bitmap.width;
    const height = image.bitmap.height;

    for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
            const pixelColor = image.getPixelColor(x, y);
            const { r, g, b } = Jimp.intToRGBA(pixelColor);

            let diffR = Math.abs(r - 127);
            let diffG = Math.abs(g - 127);
            let diffB = Math.abs(b - 127);

            let maxDiff = Math.max(diffR, diffG, diffB);

            if (maxDiff % 2 === 0) {
                hiddenBinary += "1";
            } else {
                hiddenBinary += "0";
            }
        }
    }

    return hiddenBinary;
}

// (main) 이미지 문자열 추출 
async function validateImage(imagePath) {
    let resultBinary = await readHiddenBit(imagePath);
    let resultString = binaryToString(resultBinary);
    return resultString;
}