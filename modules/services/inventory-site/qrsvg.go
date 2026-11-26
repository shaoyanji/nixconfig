package main

import (
	"fmt"
	"image/color"
	"strings"

	"github.com/boombuler/barcode/qr"
)

func xmlEscape(value string) string {
	replacer := strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;", "'", "&apos;")
	return replacer.Replace(value)
}

func qrLabelTarget(origin string, id int64) string {
	origin = strings.TrimRight(strings.TrimSpace(origin), "/")
	if origin == "" {
		origin = "http://inventory-site.local"
	}
	return fmt.Sprintf("%s/?item=%d", origin, id)
}

func renderQRLabelSVG(item Item, target string) ([]byte, error) {
	code, err := qr.Encode(target, qr.M, qr.Auto)
	if err != nil {
		return nil, err
	}
	modules := code.Bounds().Dx()
	quiet := 4
	cell := 6
	qrSize := (modules + quiet*2) * cell
	qrX := 28
	qrY := 30
	width := qrX*2 + qrSize
	textY := qrY + qrSize + 32
	height := textY + 92
	var out strings.Builder
	out.WriteString(fmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" role="img" aria-labelledby="title desc">`, width, height, width, height))
	out.WriteString(`<title id="title">Inventory asset QR label</title><desc id="desc">Printable QR label linking to the inventory asset detail.</desc>`)
	out.WriteString(fmt.Sprintf(`<rect width="%d" height="%d" rx="14" fill="#fff" stroke="#111" stroke-width="2"/>`, width, height))
	out.WriteString(fmt.Sprintf(`<rect x="%d" y="%d" width="%d" height="%d" fill="#fff"/>`, qrX, qrY, qrSize, qrSize))
	out.WriteString(`<g fill="#000">`)
	for y := 0; y < modules; y++ {
		for x := 0; x < modules; x++ {
			rgba := color.RGBAModel.Convert(code.At(x, y)).(color.RGBA)
			if rgba.R < 128 {
				out.WriteString(fmt.Sprintf(`<rect x="%d" y="%d" width="%d" height="%d"/>`, qrX+(x+quiet)*cell, qrY+(y+quiet)*cell, cell, cell))
			}
		}
	}
	out.WriteString(`</g>`)
	out.WriteString(fmt.Sprintf(`<text x="%d" y="%d" font-family="Arial,Helvetica,sans-serif" font-size="18" font-weight="700" fill="#111">%s</text>`, qrX, textY, xmlEscape(truncateRunes(item.Name, 34))))
	line2 := strings.TrimSpace(strings.Join([]string{item.Manufacturer, item.Model}, " "))
	if line2 != "" {
		out.WriteString(fmt.Sprintf(`<text x="%d" y="%d" font-family="Arial,Helvetica,sans-serif" font-size="12" fill="#333">%s</text>`, qrX, textY+22, xmlEscape(truncateRunes(line2, 48))))
	}
	line3 := "asset #" + fmt.Sprint(item.ID)
	if item.Serial != "" {
		line3 += " · SN " + item.Serial
	}
	out.WriteString(fmt.Sprintf(`<text x="%d" y="%d" font-family="Arial,Helvetica,sans-serif" font-size="11" fill="#333">%s</text>`, qrX, textY+42, xmlEscape(truncateRunes(line3, 52))))
	if item.Location != "" {
		out.WriteString(fmt.Sprintf(`<text x="%d" y="%d" font-family="Arial,Helvetica,sans-serif" font-size="10" fill="#555">%s</text>`, qrX, textY+60, xmlEscape(truncateRunes("location: "+item.Location, 54))))
	}
	out.WriteString(`</svg>`)
	return []byte(out.String()), nil
}

func truncateRunes(value string, limit int) string {
	runes := []rune(strings.TrimSpace(value))
	if len(runes) <= limit {
		return string(runes)
	}
	return string(runes[:limit-1]) + "…"
}
