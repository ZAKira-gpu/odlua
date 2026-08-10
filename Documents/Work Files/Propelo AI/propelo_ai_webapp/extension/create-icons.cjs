#!/usr/bin/env node

/**
 * Simple script to create placeholder PNG icons for Chrome extension
 * Creates solid cyan colored squares as temporary icons
 */

const fs = require('fs');
const path = require('path');

// Simple function to create a minimal PNG file
function createPNG(width, height, r, g, b) {
  // PNG file format structure
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  
  // IHDR chunk (image header)
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr.writeUInt8(8, 8); // bit depth
  ihdr.writeUInt8(2, 9); // color type (RGB)
  ihdr.writeUInt8(0, 10); // compression
  ihdr.writeUInt8(0, 11); // filter
  ihdr.writeUInt8(0, 12); // interlace
  
  const ihdrChunk = createChunk('IHDR', ihdr);
  
  // IDAT chunk (image data)
  const pixelData = [];
  for (let y = 0; y < height; y++) {
    pixelData.push(0); // filter type
    for (let x = 0; x < width; x++) {
      pixelData.push(r, g, b);
    }
  }
  
  const zlib = require('zlib');
  const compressed = zlib.deflateSync(Buffer.from(pixelData));
  const idatChunk = createChunk('IDAT', compressed);
  
  // IEND chunk (image end)
  const iendChunk = createChunk('IEND', Buffer.alloc(0));
  
  return Buffer.concat([signature, ihdrChunk, idatChunk, iendChunk]);
}

function createChunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);
  
  const typeBuffer = Buffer.from(type, 'ascii');
  
  const crc = require('zlib').crc32(Buffer.concat([typeBuffer, data]));
  const crcBuffer = Buffer.alloc(4);
  crcBuffer.writeUInt32BE(crc, 0);
  
  return Buffer.concat([length, typeBuffer, data, crcBuffer]);
}

// Create icons directory if it doesn't exist
const iconsDir = path.join(__dirname, 'icons');
if (!fs.existsSync(iconsDir)) {
  fs.mkdirSync(iconsDir);
}

console.log('🎨 Creating placeholder icons for Propelo Chrome Extension...\n');

// Propelo cyan color: #00FFFF (0, 255, 255)
const cyan = { r: 0, g: 255, b: 255 };

// Create 16x16 icon
const icon16 = createPNG(16, 16, cyan.r, cyan.g, cyan.b);
fs.writeFileSync(path.join(iconsDir, 'icon16.png'), icon16);
console.log('✅ Created icon16.png (16x16)');

// Create 48x48 icon
const icon48 = createPNG(48, 48, cyan.r, cyan.g, cyan.b);
fs.writeFileSync(path.join(iconsDir, 'icon48.png'), icon48);
console.log('✅ Created icon48.png (48x48)');

// Create 128x128 icon
const icon128 = createPNG(128, 128, cyan.r, cyan.g, cyan.b);
fs.writeFileSync(path.join(iconsDir, 'icon128.png'), icon128);
console.log('✅ Created icon128.png (128x128)');

console.log('\n🎉 All placeholder icons created successfully!');
console.log('💡 Replace these with proper Propelo logo icons for production.\n');
