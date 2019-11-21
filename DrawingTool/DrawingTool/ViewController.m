//
//  ViewController.m
//  DrawingTool
//
//  Created by mini2014a on 2019/11/20.
//  Copyright © 2019 HK. All rights reserved.
//

#import "ViewController.h"
#import "CharTableViewCell.h"
#import "UIImage+Resize.h"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>{
    int minX,minY,maxX,MaxY;
}
@property (strong, nonatomic) NSArray *charArray;
@property (strong, nonatomic) NSString *currentIndex;
@property (strong, nonatomic) NSString *currentChar;

@property (strong, nonatomic) UIBezierPath *bezierPath;
@property (strong, nonatomic) UIImage *lastDrawImage;
@property (strong, nonatomic) NSMutableArray *undoStack;
@property (strong, nonatomic) NSMutableArray *redoStack;

@end

@implementation ViewController

#pragma mark - ViewLoad
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.undoStack = [NSMutableArray array];
    self.redoStack = [NSMutableArray array];
    
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"chars.plist" ofType:nil];
    NSArray *arr = [NSArray arrayWithContentsOfFile:filepath];
    self.charArray = [[NSMutableArray alloc] initWithArray:arr];
    
    self.charListTableView.delegate = self;
    self.charListTableView.dataSource = self;
    [self.charListTableView reloadData];
    
    [self resetArea];
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.thumbImgView.layer.borderWidth=1;
    self.thumbImgView.layer.borderColor=[[UIColor lightGrayColor] CGColor];
    
    self.canvasImgView.backgroundColor=[UIColor whiteColor];
    
    CGFloat topHeight = 20;
    CGFloat bottomHeight = 0;
    if (@available(iOS 11, *)) {
        topHeight = self.view.safeAreaInsets.top;
        bottomHeight =  self.view.safeAreaInsets.bottom;
    }
    CGFloat canvasSize = 320;
    self.canvasImgView.frame = CGRectMake((self.view.frame.size.width-320)/2, topHeight, canvasSize, canvasSize);
    self.thumbImgView.frame = CGRectMake(0, topHeight, self.thumbImgView.frame.size.width, self.thumbImgView.frame.size.height);
    self.currentCharLabel.frame = CGRectMake(0, topHeight, self.view.frame.size.width, self.currentCharLabel.frame.size.height);
    self.btnView.frame = CGRectMake((self.view.frame.size.width-320)/2, topHeight+canvasSize, canvasSize, self.btnView.frame.size.height);
    self.charListTableView.frame = CGRectMake((self.view.frame.size.width-320)/2, topHeight+canvasSize+self.btnView.frame.size.height, canvasSize, self.view.frame.size.height-topHeight-bottomHeight-canvasSize-self.btnView.frame.size.height);
}

#pragma mark - IBAction
-(IBAction)onClickedSaveBtn:(id)sender{
    if (!self.currentChar || [self.currentChar isEqualToString:@""]) {
        return;
    }
    NSString  *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
    NSString *folderPath = [root stringByAppendingPathComponent:self.currentIndex];
    if (![[NSFileManager defaultManager] fileExistsAtPath:folderPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    /*
    NSString *emojiFilePath =[folderPath stringByAppendingPathComponent:@"char.txt"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:emojiFilePath]) {
        [self.currentChar writeToFile:emojiFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
*/
    NSString *filename = [self genFilename];
    NSString *path = [folderPath stringByAppendingPathComponent:filename];

    NSData *imgData =UIImageJPEGRepresentation(self.thumbImgView.image,0.98);
    [imgData writeToFile:path atomically:YES];

    [self.charListTableView reloadData];
    
    [self cleanCanvas];
}
-(IBAction)onClickedUndoBtn:(id)sender{
    UIBezierPath *undoPath = self.undoStack.lastObject;
    [self.undoStack removeLastObject];
    [self.redoStack addObject:undoPath];

    self.lastDrawImage = nil;
    self.canvasImgView.image = nil;

    for (UIBezierPath *path in self.undoStack) {
        [self drawLine:path];
        self.lastDrawImage = self.canvasImgView.image;
    }
}
#pragma mark - Draw
-(void)cleanCanvas{
    [self.undoStack removeAllObjects];
    [self.redoStack removeAllObjects];

    self.lastDrawImage = nil;
    self.canvasImgView.image = nil;
    self.canvasImgView.backgroundColor=[UIColor whiteColor];
    self.thumbImgView.image = nil;
    
    [self resetArea];
}
-(void)resetArea{
    minX=self.canvasImgView.frame.size.width;
    maxX=0;
    minY=self.canvasImgView.frame.size.height;
    MaxY=0;
}
-(void)computArea:(CGPoint)point{
    if (point.x>maxX) {
        maxX=point.x;
    }
    if (point.x<minX) {
        minX=point.x;
    }
    if (point.y>MaxY) {
        MaxY=point.y;
    }
    if (point.y<minY) {
        minY=point.y;
    }
}
- (void)drawLine:(UIBezierPath*)path
{
    UIGraphicsBeginImageContext(self.canvasImgView.frame.size);
    [self.lastDrawImage drawAtPoint:CGPointZero];
    [[UIColor blackColor] setStroke];
    [path stroke];
    self.canvasImgView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

-(void)createCropImg:(NSString *)filePath :(NSString *)newfilePath{
    [self resetArea];
    UIImage *oriimg = [UIImage imageWithContentsOfFile:filePath];
    CGImageRef imageRef=[oriimg CGImage];
    int dataHeight=(int)CGImageGetHeight(imageRef);;
    int dataWidth=(int)CGImageGetWidth(imageRef);
    CFDataRef imageData = CGDataProviderCopyData(CGImageGetDataProvider(imageRef));
    uint8_t *pixelData=(uint8_t *)CFDataGetBytePtr(imageData);
    
    for (int y=0;y<dataHeight; y++) {//right
        for (int x=0; x<dataWidth; x++) {
            int offsetPixel=4 * (dataWidth*y+x);
            int color = pixelData[offsetPixel+1];
            if (color<255) {
                [self computArea:CGPointMake(x, y)];
            }
        }
    }
    CFRelease(imageData);
    
    float outline=0;
    int dMinX = minX-outline;
    if (dMinX<0) {
        dMinX=0;
    }
    int dMaxX = maxX+outline;
    if (dMaxX>self.canvasImgView.frame.size.width) {
        dMaxX=self.canvasImgView.frame.size.width;
    }
    int dMinY = minY-outline;
    if (dMinY<0) {
        dMinY=0;
    }
    int dMaxY = MaxY+outline;
    if (dMaxY>self.canvasImgView.frame.size.height) {
        dMaxY=self.canvasImgView.frame.size.height;
    }
    int width = dMaxX-dMinX;
    int height = dMaxY-dMinY;
    CGRect cropRect = CGRectMake(dMinX, dMinY, width, height);
    CGImageRef imgRef = CGImageCreateWithImageInRect(imageRef, cropRect);
    UIImage *cropImg = [UIImage imageWithCGImage:imgRef];
    CGImageRelease(imgRef);
    //self.preview.image=cropImg;
    
    float space = 20;
    float drawX = space;
    float drawY = space;
    float maxWidth = dataWidth - space*2;
    float maxHeight = dataHeight - space*2;
    if (width>height) {
        maxHeight = maxWidth*(float)height/(float)width;
        drawY = (dataHeight - maxHeight)/2;
    }else{
        maxWidth = maxHeight*(float)width/(float)height;
        drawX = (dataWidth - maxWidth)/2;
    }
    UIGraphicsBeginImageContext(CGSizeMake(dataWidth, dataHeight));
    [cropImg drawInRect:CGRectMake(drawX, drawY, maxWidth, maxHeight)];
    UIImage *resultImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if ([[NSFileManager defaultManager] fileExistsAtPath:newfilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:newfilePath error:nil];
    }
    NSData *imgData =UIImageJPEGRepresentation(resultImg,0.98);
    [imgData writeToFile:newfilePath atomically:YES];
}
-(void)showPrevImg{
    float outline=5;
    int dMinX = minX-outline;
    if (dMinX<0) {
        dMinX=0;
    }
    int dMaxX = maxX+outline;
    if (dMaxX>self.canvasImgView.frame.size.width) {
        dMaxX=self.canvasImgView.frame.size.width;
    }
    int dMinY = minY-outline;
    if (dMinY<0) {
        dMinY=0;
    }
    int dMaxY = MaxY+outline;
    if (dMaxY>self.canvasImgView.frame.size.height) {
        dMaxY=self.canvasImgView.frame.size.height;
    }
    int width = dMaxX-dMinX;
    int height = dMaxY-dMinY;
    CGRect cropRect = CGRectMake(dMinX, dMinY, width, height);
    
    UIImage *img = [self snapshot:self.canvasImgView];
    UIImage *capImg = [img scaleAndRotateImage:self.canvasImgView.frame.size.width];

    CGImageRef imgRef = CGImageCreateWithImageInRect([capImg CGImage], cropRect);
    UIImage *cropImg = [UIImage imageWithCGImage:imgRef];
    CGImageRelease(imgRef);
    
    float dataWidth = self.canvasImgView.frame.size.width;
    float dataHeight = self.canvasImgView.frame.size.height;
    float space = 20;
    float drawX = space;
    float drawY = space;
    float maxWidth = dataWidth - space*2;
    float maxHeight = dataHeight - space*2;
    if (width>height) {
        maxHeight = maxWidth*(float)height/(float)width;
        drawY = (dataHeight - maxHeight)/2;
    }else{
        maxWidth = maxHeight*(float)width/(float)height;
        drawX = (dataWidth - maxWidth)/2;
    }
    UIGraphicsBeginImageContext(CGSizeMake(dataWidth, dataHeight));
    [[UIColor whiteColor] set];
    UIRectFill(CGRectMake(0.0, 0.0, dataWidth, dataHeight));
    [cropImg drawInRect:CGRectMake(drawX, drawY, maxWidth, maxHeight)];
    UIImage *resultImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    self.thumbImgView.image=resultImg;
}
#pragma mark - Touch
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    CGPoint currentPoint = [[touches anyObject] locationInView:self.canvasImgView];

    self.bezierPath = [UIBezierPath bezierPath];
    self.bezierPath.lineCapStyle = kCGLineCapRound;
    self.bezierPath.lineWidth = 4.0;
    [self.bezierPath moveToPoint:currentPoint];
    
    [self computArea:currentPoint];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    if (self.bezierPath == nil){
        return;
    }

    CGPoint currentPoint = [[touches anyObject] locationInView:self.canvasImgView];

    [self.bezierPath addLineToPoint:currentPoint];

    [self drawLine:self.bezierPath];
    [self computArea:currentPoint];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    if (self.bezierPath == nil){
        return;
    }

    CGPoint currentPoint = [[touches anyObject] locationInView:self.canvasImgView];

    [self.bezierPath addLineToPoint:currentPoint];

    [self drawLine:self.bezierPath];

    self.lastDrawImage = self.canvasImgView.image;

    [self.undoStack addObject:self.bezierPath];
    [self.redoStack removeAllObjects];
    self.bezierPath = nil;
    
    [self computArea:currentPoint];
    
    [self showPrevImg];
}
#pragma mark - TableView
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.charArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    CharTableViewCell *cell = (CharTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"CharTableViewCell"];
    NSDictionary *dict =[self.charArray objectAtIndex:indexPath.row];
    NSString *charStr =[dict objectForKey:@"char"];
    NSString *ascii = [dict objectForKey:@"ascii"];
    cell.charLabel.text = [NSString stringWithFormat:@"%@ (%@)",charStr,ascii];
    
    NSString  *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
    NSString *folderPath = [root stringByAppendingPathComponent:ascii];
    if ([[NSFileManager defaultManager] fileExistsAtPath:folderPath]) {
        NSMutableArray *filesArray = [[NSMutableArray alloc] init];
        for(NSString *content in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folderPath error:nil]) {
            if ([content.lowercaseString hasSuffix:@"jpg"]) {
                [filesArray addObject:content];
            }
        }

        cell.countLabel.text = [NSString stringWithFormat:@"[%ld]",filesArray.count];
        if(filesArray.count>=30){
            cell.countLabel.textColor = [UIColor greenColor];
            cell.charLabel.textColor = [UIColor greenColor];
        }else{
            cell.countLabel.textColor = [UIColor blackColor];
            cell.charLabel.textColor = [UIColor blackColor];
        }
    }else{
        cell.countLabel.text = @"";
    }

    if ([charStr isEqualToString:self.currentChar]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else{
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *dict =[self.charArray objectAtIndex:indexPath.row];
    NSString *charIndex = [dict objectForKey:@"ascii"];
    NSString *charStr =[dict objectForKey:@"char"];
    self.currentChar =charStr;
    
    self.currentCharLabel.text = self.currentChar;
    self.currentIndex = charIndex;
    [self.charListTableView reloadData];
    
    [self cleanCanvas];
}

#pragma mark - Util
-(NSString *)genFilename{
    NSString *uuidStr = [[[NSUUID UUID] UUIDString] substringToIndex:4];
    int x = arc4random() % 100;
    NSDateFormatter* f = [[NSDateFormatter alloc] init];
    NSLocale* languageLocal=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [f setLocale:languageLocal];
    [f setDateFormat:@"MMddHHmmss"];
    NSString *fn = [NSString stringWithFormat:@"%@_%@%d.jpg",uuidStr, [f stringFromDate:[NSDate date]],x];
    return fn;
}
- (UIImage *)snapshot:(UIView *)view{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
@end
