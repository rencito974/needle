#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

UIColor *NeedleDominantColor(UIImage *image) {
    if (!image) return [UIColor colorWithWhite:0.08 alpha:1.0];
    CGSize s = CGSizeMake(32, 32);
    UIGraphicsBeginImageContextWithOptions(s, YES, 1);
    [image drawInRect:CGRectMake(0, 0, s.width, s.height)];
    UIImage *small = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGImageRef cg = small.CGImage;
    if (!cg) return [UIColor colorWithWhite:0.08 alpha:1.0];
    size_t w = CGImageGetWidth(cg);
    size_t h = CGImageGetHeight(cg);
    uint8_t *px = calloc(w * h * 4, sizeof(uint8_t));
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(px, w, h, 8, w * 4, cs,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);

    uint64_t r = 0, g = 0, b = 0;
    uint64_t weighted = 0;
    NSUInteger n = w * h;
    for (NSUInteger i = 0; i < n; i++) {
        uint8_t pr = px[i * 4];
        uint8_t pg = px[i * 4 + 1];
        uint8_t pb = px[i * 4 + 2];
        uint8_t maxc = MAX(MAX(pr, pg), pb);
        uint8_t minc = MIN(MIN(pr, pg), pb);
        uint64_t sat = (uint64_t)(maxc - minc);
        uint64_t weight = sat > 30 ? 6 : 1;
        r += (uint64_t)pr * weight;
        g += (uint64_t)pg * weight;
        b += (uint64_t)pb * weight;
        weighted += weight;
    }
    free(px);
    CGContextRelease(ctx);
    CGColorSpaceRelease(cs);
    if (weighted == 0) return [UIColor colorWithWhite:0.08 alpha:1.0];
    CGFloat rf = (CGFloat)(r / weighted) / 255.0;
    CGFloat gf = (CGFloat)(g / weighted) / 255.0;
    CGFloat bf = (CGFloat)(b / weighted) / 255.0;
    CGFloat luma = 0.2126 * rf + 0.7152 * gf + 0.0722 * bf;
    CGFloat scale = luma > 0.55 ? 0.55 : 0.92;
    return [UIColor colorWithRed:rf * scale green:gf * scale blue:bf * scale alpha:1.0];
}

static UIColor *_NeedlePalette = nil;

void NeedleSetPalette(UIColor *c) {
    if (!c) return;
    _NeedlePalette = c;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NeedlePaletteChanged" object:c];
}

UIColor *NeedleCurrentColor(void) {
    return _NeedlePalette ?: [UIColor colorWithWhite:0.08 alpha:1.0];
}

UIColor *NeedleContrastColor(void) {
    UIColor *c = NeedleCurrentColor();
    CGFloat r, g, b, a;
    [c getRed:&r green:&g blue:&b alpha:&a];
    CGFloat luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    return luma > 0.5 ? [UIColor colorWithWhite:0.08 alpha:1.0] : [UIColor whiteColor];
}
