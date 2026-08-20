// Convert base_font.txt → assembly (stdout) for Rotoskop generate.
function parseFont(text) {
  var lines = text.split(/\r?\n/);
  var font = {};
  var i = 0;
  while (i < lines.length) {
    var line = lines[i];
    if (line.indexOf("0x") === 0) {
      var parts = line.split(/\s+/);
      var charCode = parseInt(parts[0], 16);
      i++;
      var rows = [];
      for (var r = 0; r < 8 && i < lines.length; r++) {
        var row = lines[i];
        if (row === "") break;
        rows.push(row);
        i++;
      }
      while (rows.length < 8) rows.push("-------");
      font[charCode] = rows;
    } else {
      i++;
    }
  }
  return font;
}

function rowToByte(row) {
  var v = 0;
  for (var bit = 0; bit < row.length; bit++) {
    if (row.charAt(bit) === "X") v |= (1 << bit);
  }
  return v;
}

function hex2(n) {
  var s = n.toString(16).toUpperCase();
  return (s.length < 2 ? "0" : "") + s;
}

var font = parseFont(read("src/runes/base_font.txt"));
print("; Base font data - 8 bytes per character\n");
print("; Characters 0x20-0x7F (96 characters)\n");
print("; Each character is 8 rows, pixels stored left-to-right as low-bit to high-bit\n");
print("\n");
print("base_font:\n");

for (var code = 0x20; code < 0x80; code++) {
  if (font[code]) {
    var rows = font[code];
    if (code >= 0x20 && code < 0x7F) {
      var ch = String.fromCharCode(code);
      if (ch === "'" || ch === "\\") ch = "\\" + ch;
      print("    ; 0x" + hex2(code) + " '" + ch + "'\n");
    } else {
      print("    ; 0x" + hex2(code) + " DEL\n");
    }
    var bytes = [];
    for (var r = 0; r < 8; r++) bytes.push("$" + hex2(rowToByte(rows[r])));
    print("    .byte " + bytes.join(", ") + "\n");
  } else {
    print("    ; 0x" + hex2(code) + " (missing)\n");
    print("    .byte $00, $00, $00, $00, $00, $00, $00, $00\n");
  }
}
