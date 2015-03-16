//
//  ProfileController.m
//  v-Channel
//
//  Created by Sergey Seitov on 16.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ProfileController.h"
#import "AppDelegate.h"
#import <Parse/Parse.h>
#import "Storage.h"
#import "MBProgressHUD.h"

@interface ProfileController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIActionSheetDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIButton *logoButton;
@property (weak, nonatomic) IBOutlet UIButton *signUpButton;
@property (strong, nonatomic) UIImageView *profileImage;
@property (weak, nonatomic) IBOutlet UITextField *login;
@property (weak, nonatomic) IBOutlet UITextField *password;
@property (weak, nonatomic) IBOutlet UITextField *displayName;

- (IBAction)changeLogo:(UIButton *)sender;
- (IBAction)signUp:(UIButton *)sender;

@end

@implementation ProfileController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _profileImage = [[UIImageView alloc] initWithFrame:_logoButton.bounds];
    _profileImage.layer.cornerRadius = _profileImage.frame.size.width/2;
    _profileImage.clipsToBounds = YES;
    
    _signUpButton.layer.borderWidth = 1.0;
    _signUpButton.layer.masksToBounds = YES;
    _signUpButton.layer.cornerRadius = 7.0;
    _signUpButton.layer.borderColor = _signUpButton.backgroundColor.CGColor;
    
    if (![AppDelegate isPad]) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                              target:self
                                                                                              action:@selector(goBack)];
    }
    [self updateUI];
}

- (void)goBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)updateUI
{
    if ([PFUser currentUser]) {
        PFUser* user = [PFUser currentUser];
        _login.text = user.username;
        _login.enabled = NO;
        _password.enabled = NO;
        _displayName.text = user[@"displayName"];
        NSData* photoData = user[@"photo"];
        if (photoData) {
            _profileImage.image = [UIImage imageWithData:photoData];
            [_logoButton addSubview:_profileImage];
        }
        [_signUpButton setTitle:@"Update" forState:UIControlStateNormal];
    }
}

#pragma mark - Create Profile

- (IBAction)changeLogo:(UIButton *)sender
{
    // Preset an action sheet which enables the user to take a new picture or select and existing one.
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel"  destructiveButtonTitle:nil otherButtonTitles:@"Take Photo", @"Choose Existing", nil];
    
    // Show the action sheet
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 2) {
        return;
    }
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    
    if (imagePicker) {
        // set the delegate and source type, and present the image picker
        imagePicker.delegate = self;
        if (0 == buttonIndex) {
            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
            } else {
                // Problem with camera, alert user
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Camera" message:@"Please use a camera enabled device" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
                return;
            }
        }
        else if (1 == buttonIndex) {
            imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            imagePicker.modalPresentationStyle = UIModalPresentationFormSheet;
        }
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// Change image resolution (auto-resize to fit)
- (UIImage *)scaleImage:(UIImage*)image toResolution:(int)resolution
{
    CGImageRef imgRef = [image CGImage];
    CGFloat width = CGImageGetWidth(imgRef);
    CGFloat height = CGImageGetHeight(imgRef);
    CGRect bounds = CGRectMake(0, 0, width, height);
    
    //if already at the minimum resolution, return the orginal image, otherwise scale
    if (width <= resolution && height <= resolution) {
        return image;
        
    } else {
        CGFloat ratio = width/height;
        
        if (ratio > 1) {
            bounds.size.width = resolution;
            bounds.size.height = bounds.size.width / ratio;
        } else {
            bounds.size.height = resolution;
            bounds.size.width = bounds.size.height * ratio;
        }
    }
    
    UIGraphicsBeginImageContext(bounds.size);
    [image drawInRect:CGRectMake(0.0, 0.0, bounds.size.width, bounds.size.height)];
    UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return imageCopy;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    // Don't block the UI when writing the image to documents
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // We only handle a still image
        UIImage *imageToSave = [self scaleImage:(UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage]
                                   toResolution:128];
        dispatch_async(dispatch_get_main_queue(), ^{
            _profileImage.image = imageToSave;
            if (_profileImage.superview) {
                [_profileImage removeFromSuperview];
            }
            [_logoButton addSubview:_profileImage];
        });
    });
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - SignUp

- (void)errorLogin
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error signup"
                                                    message:@"Check your login, may be this login already exists"
                                                   delegate:nil
                                          cancelButtonTitle:@"Ok"
                                          otherButtonTitles:nil, nil];
    [alert show];
}

- (void)createNewUserWithLogin:(NSString*)login password:(NSString*)password
{
    PFUser* user = [PFUser user];
    user.username = login;
    user.password = password;
    user.email = login;
    if (!user.username || !user.password) {
        [self errorLogin];
        return;
    }
    if (_displayName.text) {
        user[@"displayName"] = _displayName.text;
    }
    if (_profileImage.image) {
        NSData *photo = UIImageJPEGRepresentation(_profileImage.image, .5);
        user[@"photo"] = photo;
    }
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [user signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        if (!error) {
            [user saveInBackground];
            [PFInstallation currentInstallation][@"userId"] = _login.text;
            [[PFInstallation currentInstallation] saveInBackground];
            [Storage saveLogin:_login.text];
            [Storage savePassword:_password.text];
            [self updateUI];
        } else {
            NSString *errorString = [error userInfo][@"error"];
            NSLog(@"%@", errorString);
            [self errorLogin];
        }
    }];
}

- (IBAction)signUp:(UIButton *)sender
{
    if ([PFUser currentUser]) {
        PFUser* user = [PFUser currentUser];
        user[@"displayName"] = _displayName.text;
        if (_profileImage.image) {
            NSData *photo = UIImageJPEGRepresentation(_profileImage.image, .5);
            user[@"photo"] = photo;
        }
        [user saveInBackground];
    } else {
        if (!_login.text || !_password.text) {
            [self errorLogin];
            return;
        }
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [PFUser logInWithUsernameInBackground:_login.text password:_password.text block:^(PFUser *user, NSError *error) {
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            if (user) {
                [self updateUI];
            } else {
                [self createNewUserWithLogin:_login.text password:_password.text];
            }
        }];
    }
}

@end