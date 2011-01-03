//
//  NSManagedObjectModel+KTExtensions.h
//  KTComponents
//
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>


@interface NSManagedObjectModel ( KTExtensions )

/*! returns an autoreleased model from "KTComponents<_aVersion>.mom"
 passing in nil for aVersion yields default model
 */
+ (NSManagedObjectModel *)modelWithVersion:(NSString *)aVersion;


+ (id)modelWithPath:(NSString *)aPath;
+ (id)modelWithURL:(NSURL *)aFileURL;

- (void)makeGeneric;

- (NSEntityDescription *)entityWithName:(NSString *)aName;
- (void)addEntity:(NSEntityDescription *)anEntity;
- (void)removeEntity:(NSEntityDescription *)anEntity;

- (BOOL)hasEntityNamed:(NSString *)aString;

- (void)prettyPrintDescription;

// Fetch request templates
- (NSFetchRequest *)fetchRequestFromTemplateWithName:(NSString *)name
								substitutionVariable:(id)substitution
											  forKey:(NSString *)substitutionKey;

@end
