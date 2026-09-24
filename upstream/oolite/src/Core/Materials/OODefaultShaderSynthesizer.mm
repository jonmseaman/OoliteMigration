/*

OODefaultShaderSynthesizer.m


Copyright © 2011-2013 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#import "OODefaultShaderSynthesizer.h"
#include "oofnd/objc/OORuntime.h"
#import "OOMesh.h"
#import "OOTexture.h"
#import "OOColor.h"

#import "OOStringBridge.h"
#import "OOPListView.h"
#import "NSDictionaryOOExtensions.h"
#import "OOMaterialSpecifier.h"
#import "ResourceManager.h"
#import "OOFoundationException.h"
#import "OOFoundationBridge.h"
#include "oofnd/StdLib.hpp"
#include "oofnd/String.hpp"

/* 
 * GNUstep 1.20.1 does not support NSIntegerHashCallBacks but uses 
 * NSIntHashCallBacks instead. NSIntHashCallBacks was deprecated in favor of
 * NSIntegerHashCallBacks in GNUstep versions later than 1.20.1. If we move to
 * a newer GNUstep version for Oolite the #define below may not be necessary
 * anymore but for now we need it to be able to build. - Nikos 20120208.
*/
#if OOLITE_GNUSTEP
#define NSIntegerHashCallBacks	NSIntHashCallBacks
#endif


namespace {

oo::PList CanonicalizeMaterialSpecifier(const oo::PList &spec, const std::optional<std::string> &materialKey);

}	// namespace

static NSString *FormatFloat(double value);


@interface OODefaultShaderSynthesizer: OOObject
{
@private
	oo::PList					_configuration;
	std::optional<std::string>	_materialKey;
	std::optional<std::string>	_entityName;
	
	std::string					_vertexShader;
	std::string					_fragmentShader;
	NSMutableArray				*_textures;
	NSMutableDictionary			*_uniforms;
	
	NSMutableString				*_attributes;
	NSMutableString				*_varyings;
	NSMutableString				*_vertexUniforms;
	NSMutableString				*_fragmentUniforms;
	NSMutableString				*_vertexHelpers;
	NSMutableString				*_fragmentHelpers;
	NSMutableString				*_vertexBody;
	NSMutableString				*_fragmentPreTextures;
	NSMutableString				*_fragmentTextureLookups;
	NSMutableString				*_fragmentBody;
	
	// _texturesByName: dictionary mapping texture file names to texture specifications.
	NSMutableDictionary			*_texturesByName;
	// _textureIDs: dictionary mapping texture file names to numerical IDs used to name variables.
	NSMutableDictionary			*_textureIDs;
	// _sampledTextures: hash of integer texture IDs for which we’ve set up a sample.
	std::unordered_set<NSUInteger>	_sampledTextures;	// was an integer hash table (bead oo-3rb.20)
	
	NSMutableDictionary			*_uniformBindingNames;
	
	NSUInteger					_usesNormalMap: 1,
								_usesDiffuseTerm: 1,
								_constZNormal: 1,
								_haveDiffuseLight: 1,
	
	// Completion flags for various generation stages.
								_completed_writeFinalColorComposite: 1,
								_completed_writeDiffuseColorTerm: 1,
								_completed_writeSpecularLighting: 1,
								_completed_writeLightMaps: 1,
								_completed_writeDiffuseLighting: 1,
								_completed_writeDiffuseColorTermIfNeeded: 1,
								_completed_writeVertexPosition: 1,
								_completed_writeNormalIfNeeded: 1,
						//		_completedwriteNormal: 1,
								_completed_writeLightVector: 1,
								_completed_writeEyeVector: 1, 
								_completed_writeTotalColor: 1,
								_completed_writeTextureCoordRead: 1,
								_completed_writeVertexTangentBasis: 1;
	
#ifndef NDEBUG
	std::unordered_set<SEL>		_stagesInProgress;	// by pointer identity, as the hash table was
#endif
}

- (id) initWithMaterialConfiguration:(const oo::PList &)configuration
						 materialKey:(const std::optional<std::string> &)materialKey
						  entityName:(const std::optional<std::string> &)name;

- (BOOL) run;

- (std::string) vertexShader;
- (std::string) fragmentShader;
- (oo::PList) textureSpecifications;		// an array
- (oo::PList) uniformSpecifications;		// a dictionary

- (std::optional<std::string>) materialKey;
- (std::optional<std::string>) entityName;

- (void) createTemporaries;
- (void) destroyTemporaries;

- (void) composeVertexShader;
- (void) composeFragmentShader;

// Write various types of declarations.
- (void) appendVariable:(NSString *)name ofType:(NSString *)type withPrefix:(NSString *)prefix to:(NSMutableString *)buffer;
- (void) addAttribute:(NSString *)name ofType:(NSString *)type;
- (void) addVarying:(NSString *)name ofType:(NSString *)type;
- (void) addVertexUniform:(NSString *)name ofType:(NSString *)type;
- (void) addFragmentUniform:(NSString *)name ofType:(NSString *)type;

// Create or retrieve a uniform variable name for a given binding.
- (NSString *) defineBindingUniform:(NSDictionary *)binding ofType:(NSString *)type;

- (NSString *) readRGBForTextureSpec:(NSDictionary *)textureSpec mapName:(NSString *)mapName;	// Generate a read for an RGB value, or a single channel splatted across RGB.
- (NSString *) readOneChannelForTextureSpec:(NSDictionary *)textureSpec mapName:(NSString *)mapName;	// Generate a read for a single channel.

// Details of texture setup; generally use -read*ForTextureSpec:mapName: instead.
- (NSUInteger) textureIDForSpec:(NSDictionary *)textureSpec;
- (void) setUpOneTexture:(NSDictionary *)textureSpec;
- (void) getSampleName:(NSString **)outSampleName andSwizzleOp:(NSString **)outSwizzleOp forTextureSpec:(NSDictionary *)textureSpec;


/*	Stages. These should only be called through the REQUIRE_STAGE macro to
	avoid duplicated code and ensure data depedencies are met.
*/


/*	writeTextureCoordRead
	Generate vec2 texCoords.
*/
- (void) writeTextureCoordRead;

/*	writeDiffuseColorTermIfNeeded
	Generates and populates the fragment shader value vec3 diffuseColor, unless
	the diffuse term is black. If a diffuseColor is generated, _usesDiffuseTerm
	is set. The value will be const if possible.
	See also: writeDiffuseColorTerm.
*/
- (void) writeDiffuseColorTermIfNeeded;

/*	writeDiffuseColorTerm
	Generates vec3 diffuseColor unconditionally – that is, even if the diffuse
	term is black.
	See also: writeDiffuseColorTermIfNeeded.
*/
- (void) writeDiffuseColorTerm;

/*	writeDiffuseLighting
	Generate the fragment variable vec3 diffuseLight and add Lambertian and
	ambient terms to it.
*/
- (void) writeDiffuseLighting;

/*	writeLightVector
	Generate the fragment variable vec3 lightVector (unit vector) for temporary
	lighting. Calling this if lighting mode is kLightingUniform will cause an
	exception.
*/
- (void) writeLightVector;

/*	writeEyeVector
	Generate vec3 lightVector, the normalized direction from the fragment to
	the light source.
*/
- (void) writeEyeVector;

/*	writeVertexTangentBasis
	Generates tangent space basis matrix (TBN) in vertex shader, if in tangent-
	space lighting mode. If not, an exeception is raised.
*/
- (void) writeVertexTangentBasis;

/*	writeNormalIfNeeded
	Writes fragment variable vec3 normal if necessary. Otherwise, it sets
	_constZNormal, indicating that the normal is always (0, 0, 1).
	
	See also: writeNormal.
*/
- (void) writeNormalIfNeeded;

/*	writeNormal
	Generates vec3 normal unconditionally – if _constZNormal is set, normal will
	be const vec3 normal = vec3 (0.0, 0.0, 1.0).
*/
- (void) writeNormal;

/*	writeSpecularLighting
	Calculate specular writing and add it to totalColor.
*/
- (void) writeSpecularLighting;

/*	writeLightMaps
	Add emission and illumination maps to totalColor.
*/
- (void) writeLightMaps;

/*	writeVertexPosition
	Calculate vertex position and write it to gl_Position.
*/
- (void) writeVertexPosition;

/*	writeTotalColor
	Generate vec3 totalColor, the accumulator for output colour values.
*/
- (void) writeTotalColor;

/*	writeFinalColorComposite
	This stage writes the final fragment shader. It also pulls in other stages
	through dependencies.
*/
- (void) writeFinalColorComposite;


/*
	REQUIRE_STAGE(): pull in the required stage. A stage must have a
	zero-parameter method and a matching _completed_stage instance variable.
	
	In debug/testrelease builds, this dispatches through performStage: which
	checks for recursive calls.
*/
#ifndef NDEBUG
#define REQUIRE_STAGE(NAME) if (!_completed_##NAME) { [self performStage:@selector(NAME)]; _completed_##NAME = YES; }
- (void) performStage:(SEL)stage;
#else
#define REQUIRE_STAGE(NAME) if (!_completed_##NAME) { [self NAME]; _completed_##NAME = YES; }
#endif

@end


static NSString *GetExtractMode(NSDictionary *textureSpecifier);


BOOL OOSynthesizeMaterialShader(const oo::PList &configuration, const std::optional<std::string> &materialKey, const std::optional<std::string> &entityName, std::string *outVertexShader, std::string *outFragmentShader, oo::PList *outTextureSpecs, oo::PList *outUniformSpecs)
{
	NSCParameterAssert(!configuration.isNull() && outVertexShader != NULL && outFragmentShader != NULL && outTextureSpecs != NULL && outUniformSpecs != NULL);
	
	@autoreleasepool
	{
		OODefaultShaderSynthesizer *synthesizer = [[OODefaultShaderSynthesizer alloc]
												   initWithMaterialConfiguration:configuration
																	 materialKey:materialKey
																	  entityName:entityName];
		[synthesizer autorelease];
	
		BOOL OK = [synthesizer run];
		if (OK)
		{
			*outVertexShader = [synthesizer vertexShader];
			*outFragmentShader = [synthesizer fragmentShader];
			*outTextureSpecs = [synthesizer textureSpecifications];
			*outUniformSpecs = [synthesizer uniformSpecifications];
		}
		else
		{
			outVertexShader->clear();
			outFragmentShader->clear();
			*outTextureSpecs = oo::PList();
			*outUniformSpecs = oo::PList();
		}
	}
	
	return YES;
}


@implementation OODefaultShaderSynthesizer

- (id) initWithMaterialConfiguration:(const oo::PList &)configuration
						 materialKey:(const std::optional<std::string> &)materialKey
						  entityName:(const std::optional<std::string> &)name
{
	if ((self = [super init]))
	{
		_configuration = CanonicalizeMaterialSpecifier(configuration, materialKey);
		_materialKey = materialKey;
		// _entityName stays nil: upstream copied it from itself ([_entityName copy]) instead of name.
	}
	
	return self;
}


- (void) dealloc
{
	[self destroyTemporaries];
	DESTROY(_textures);
	
    [super dealloc];
}


- (std::string) vertexShader
{
	return _vertexShader;
}


- (std::string) fragmentShader
{
	return _fragmentShader;
}


- (oo::PList) textureSpecifications
{
	return oo::PListFrom(_textures);
}


- (oo::PList) uniformSpecifications
{
	return oo::PListFrom(_uniforms);
}


- (BOOL) run
{
	[self createTemporaries];
	_uniforms = [[NSMutableDictionary alloc] init];
	[_vertexBody appendString:@"void main(void)\n{\n"];
	[_fragmentPreTextures appendString:@"void main(void)\n{\n"];
	
	@try
	{
		REQUIRE_STAGE(writeFinalColorComposite);
		
		[self composeVertexShader];
		[self composeFragmentShader];
	}
	@catch (OOException *exception)
	{
		// Error should have been reported already.
		return NO;
	}
	@catch (OOFoundationException *exception)
	{
		// Error should have been reported already.
		return NO;
	}
	@finally
	{
		[self destroyTemporaries];
	}
	
	return YES;
}

- (std::optional<std::string>) materialKey
{
	return _materialKey;
}


- (std::optional<std::string>) entityName
{
	return _entityName;
}


// MARK: - Utilities

static void AppendIfNotEmpty(NSMutableString *buffer, NSString *segment, NSString *name)
{
	if ([segment length] > 0)
	{
		if ([buffer length] > 0)  [buffer appendString:@"\n\n"];
		if ([name length] > 0)  [buffer appendFormat:@"// %@\n", name];
		[buffer appendString:segment];
	}
}


static NSString *GetExtractMode(NSDictionary *textureSpecifier)
{
	NSString *result = nil;
	
	NSString *rawMode = oo::PListView(textureSpecifier).get<NSString *>(kOOTextureSpecifierSwizzleKey);
	if (rawMode != nil)
	{
		NSUInteger length = [rawMode length];
		if (1 <= length && length <= 4)
		{
			static NSCharacterSet *nonRGBACharset = nil;
			if (nonRGBACharset == nil)
			{
				nonRGBACharset = [[[NSCharacterSet characterSetWithCharactersInString:@"rgba"] invertedSet] retain];
			}
			
			if ([rawMode rangeOfCharacterFromSet:nonRGBACharset].location == NSNotFound)
			{
				result = rawMode;
			}
		}
	}
	
	return result;
}


- (void) appendVariable:(NSString *)name ofType:(NSString *)type withPrefix:(NSString *)prefix to:(NSMutableString *)buffer
{
	NSUInteger typeDeclLength = [prefix length] + [type length] + 1;
	NSUInteger padding = (typeDeclLength < 20) ? (23 - typeDeclLength) / 4 : 1;
	[buffer appendFormat:@"%@ %@%@%@;\n", prefix, type, oo::NSStringFrom(oo::str::tabString(padding)), name];
}


- (void) addAttribute:(NSString *)name ofType:(NSString *)type
{
	[self appendVariable:name ofType:type withPrefix:@"attribute" to:_attributes];
}


- (void) addVarying:(NSString *)name ofType:(NSString *)type
{
	[self appendVariable:name ofType:type withPrefix:@"varying" to:_varyings];
}


- (void) addVertexUniform:(NSString *)name ofType:(NSString *)type
{
	[self appendVariable:name ofType:type withPrefix:@"uniform" to:_vertexUniforms];
}


- (void) addFragmentUniform:(NSString *)name ofType:(NSString *)type
{
	[self appendVariable:name ofType:type withPrefix:@"uniform" to:_fragmentUniforms];
}


- (NSString *) defineBindingUniform:(NSDictionary *)binding ofType:(NSString *)type
{
	NSString *name = oo::PListView(binding).get<NSString *>(@"binding");
	NSParameterAssert([name length] > 0);
	
	NSMutableDictionary *bindingSpec = [[binding mutableCopy] autorelease];
	if (oo::PListView(bindingSpec).get<NSString *>(@"type") == nil)  [bindingSpec setObject:@"binding" forKey:@"type"];
	
	// Use existing uniform if one is defined.
	NSString *uniformName = [_uniformBindingNames objectForKey:bindingSpec];
	if (uniformName != nil)  return uniformName;
	
	// Capitalize first char of name, and prepend u.
	unichar firstChar = toupper([name characterAtIndex:0]);
	NSString *baseName = [NSString stringWithFormat:@"u%C%@", firstChar, [name substringFromIndex:1]];
	
	// Ensure name is unique.
	name = baseName;
	unsigned idx = 1;
	while ([_uniforms objectForKey:name] != nil)
	{
		name = [NSString stringWithFormat:@"%@%u", baseName, ++idx];
	}
	
	[self addFragmentUniform:name ofType:type];
	
	[_uniforms setObject:bindingSpec forKey:name];
	[_uniformBindingNames setObject:name forKey:bindingSpec];
	
	return name;
}


- (void) composeVertexShader
{
	while ([_vertexBody hasSuffix:@"\t\n"])
	{
		[_vertexBody deleteCharactersInRange:(NSRange){ [_vertexBody length] - 2, 2 }];
	}
	[_vertexBody appendString:@"}"];
	
	NSMutableString *vertexShader = [NSMutableString string];
	AppendIfNotEmpty(vertexShader, _attributes, @"Attributes");
	AppendIfNotEmpty(vertexShader, _vertexUniforms, @"Uniforms");
	AppendIfNotEmpty(vertexShader, _varyings, @"Varyings");
	AppendIfNotEmpty(vertexShader, _vertexHelpers, @"Helper functions");
	AppendIfNotEmpty(vertexShader, _vertexBody, nil);
	
	_vertexShader = oo::StdString(vertexShader);
}


- (void) composeFragmentShader
{
	while ([_fragmentBody hasSuffix:@"\t\n"])
	{
		[_fragmentBody deleteCharactersInRange:(NSRange){ [_fragmentBody length] - 2, 2 }];
	}
	
	NSMutableString *fragmentShader = [NSMutableString string];
	AppendIfNotEmpty(fragmentShader, _fragmentUniforms, @"Uniforms");
	AppendIfNotEmpty(fragmentShader, _varyings, @"Varyings");
	AppendIfNotEmpty(fragmentShader, _fragmentHelpers, @"Helper functions");
	AppendIfNotEmpty(fragmentShader, _fragmentPreTextures, nil);
	if ([_fragmentTextureLookups length] > 0)
	{
		[fragmentShader appendString:@"\t\n\t// Texture lookups\n"];
		[fragmentShader appendString:_fragmentTextureLookups];
	}
	[fragmentShader appendString:@"\t\n"];
	[fragmentShader appendString:_fragmentBody];
	[fragmentShader appendString:@"}"];
	
	_fragmentShader = oo::StdString(fragmentShader);
}


/*
	Build a key for a texture specifier, taking all texture configuration
	options into account and ignoring the other stuff that might be there.
	
	FIXME: efficiency and stuff.
*/
static NSString *KeyFromTextureParameters(NSString *name, OOTextureFlags options, float anisotropy, float lodBias)
{
#ifndef NDEBUG
	options = OOApplyTextureOptionDefaults(options);
#endif
	
	// Extraction modes are ignored in synthesized shaders, since we use swizzling instead.
	options &= ~kOOTextureExtractChannelMask;
	
	return [NSString stringWithFormat:@"%@:%X:%g:%g", name, options, anisotropy, lodBias];
}

static NSString *KeyFromTextureSpec(NSDictionary *spec)
{
	NSString *texName = nil;
	OOTextureFlags texOptions;
	float anisotropy, lodBias;
	if (!OOInterpretTextureSpecifier(spec, &texName, &texOptions, &anisotropy, &lodBias, YES))
	{
		// OOInterpretTextureSpecifier() will have logged something.
		[OOException raise:OOGenericException format:"Invalid texture specifier"];
	}
	
	return KeyFromTextureParameters(texName, texOptions, anisotropy, lodBias);
}


- (NSUInteger) assignIDForTexture:(NSDictionary *)spec
{
	NSParameterAssert(spec != nil);
	
	// extract_channel doesn't affect uniqueness, and we don't want OOTexture to do actual extraction.
	if ([spec objectForKey:kOOTextureSpecifierSwizzleKey] != nil)
	{
		spec = [spec dictionaryByRemovingObjectForKey:kOOTextureSpecifierSwizzleKey];
	}
	
	NSString *texName = nil;
	OOTextureFlags texOptions;
	float anisotropy, lodBias;
	if (!OOInterpretTextureSpecifier(spec, &texName, &texOptions, &anisotropy, &lodBias, YES))
	{
		// OOInterpretTextureSpecifier() will have logged something.
		[OOException raise:OOGenericException format:"Invalid texture specifier"];
	}
	
	if (texOptions & kOOTextureAllowCubeMap)
	{
		// cube_map = true; fail regardless of whether actual texture qualifies.
		OOLogERR(@"material.synthesis.error.cubeMap", @"The material \"%@\" of \"%@\" specifies a cube map texture, but doesn't have custom shaders. Cube map textures are not supported with the default shaders.", oo::NSStringOrNil([self materialKey]), oo::NSStringOrNil([self entityName]));
		[OOException raise:OOGenericException format:"Invalid material"];
	}
	
	NSString *key = KeyFromTextureParameters(texName, texOptions, anisotropy, lodBias);
	NSUInteger texID;
	NSObject *existing = [_texturesByName objectForKey:key];
	if (existing == nil)
	{
		texID = [_texturesByName count];
		NSNumber	*texIDObj = [NSNumber numberWithUnsignedInteger:texID];
		NSString	*texUniform = [NSString stringWithFormat:@"uTexture%zu", texID];
		
#ifndef NDEBUG
		BOOL useInternalFormat = NO;
#else
		BOOL useInternalFormat = YES;
#endif
		
		[_textures addObject:OOMakeTextureSpecifier(texName, texOptions, anisotropy, lodBias, useInternalFormat)];
		[_texturesByName setObject:spec forKey:key];
		[_textureIDs setObject:texIDObj forKey:key];
		[_uniforms setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"texture", @"type", texIDObj, @"value", nil]
					  forKey:texUniform];
		
		[self addFragmentUniform:texUniform ofType:@"sampler2D"];
	}
	else
	{
		texID = oo::PListView(_textureIDs).get<NSUInteger>(texName);
	}
	
	return texID;
}


- (NSUInteger) textureIDForSpec:(NSDictionary *)textureSpec
{
	return oo::PListView(_textureIDs).get<NSUInteger>(KeyFromTextureSpec(textureSpec));
}


- (void) setUpOneTexture:(NSDictionary *)textureSpec
{
	if (textureSpec == nil)  return;
	
	REQUIRE_STAGE(writeTextureCoordRead);
	
	NSUInteger texID = [self assignIDForTexture:textureSpec];
	if (_sampledTextures.insert(texID).second)
	{
		[_fragmentTextureLookups appendFormat:@"\tvec4 tex%zuSample = texture2D(uTexture%zu, texCoords);  // %@\n", texID, texID, oo::PListView(textureSpec).get<NSString *>(kOOTextureSpecifierNameKey)];
	}
}


- (void) getSampleName:(NSString **)outSampleName andSwizzleOp:(NSString **)outSwizzleOp forTextureSpec:(NSDictionary *)textureSpec
{
	NSParameterAssert(outSampleName != NULL && outSwizzleOp != NULL && textureSpec != nil);
	
	[self setUpOneTexture:textureSpec];
	NSUInteger	texID = [self textureIDForSpec:textureSpec];
	
	*outSampleName = [NSString stringWithFormat:@"tex%zuSample", texID];
	*outSwizzleOp = GetExtractMode(textureSpec);
}


- (NSString *) readRGBForTextureSpec:(NSDictionary *)textureSpec mapName:(NSString *)mapName
{
	NSString *sample, *swizzle;
	[self getSampleName:&sample andSwizzleOp:&swizzle forTextureSpec:textureSpec];
	
	if (swizzle == nil)
	{
		return [sample stringByAppendingString:@".rgb"];
	}
	
	NSUInteger channelCount = [swizzle length];
	
	if (channelCount == 1)
	{
		return [NSString stringWithFormat:@"%@.%@%@%@", sample, swizzle, swizzle, swizzle];
	}
	else if (channelCount == 3)
	{
		return [NSString stringWithFormat:@"%@.%@", sample, swizzle];
	}
	
	OOLogWARN(@"material.synthesis.warning.extractionMismatch", @"The %@ map for material \"%@\" of \"%@\" specifies %zu channels to extract, but only %@ may be used.", mapName, oo::NSStringOrNil([self materialKey]), oo::NSStringOrNil([self entityName]), channelCount, @"1 or 3");
	return nil;
}


- (NSString *) readOneChannelForTextureSpec:(NSDictionary *)textureSpec mapName:(NSString *)mapName
{
	NSString *sample, *swizzle;
	[self getSampleName:&sample andSwizzleOp:&swizzle forTextureSpec:textureSpec];
	
	if (swizzle == nil)
	{
		return [sample stringByAppendingString:@".r"];
	}
	
	NSUInteger channelCount = [swizzle length];
	
	if (channelCount == 1)
	{
		return [NSString stringWithFormat:@"%@.%@", sample, swizzle];
	}
	
	OOLogWARN(@"material.synthesis.warning.extractionMismatch", @"The %@ map for material \"%@\" of \"%@\" specifies %zu channels to extract, but only %@ may be used.", mapName, oo::NSStringOrNil([self materialKey]), oo::NSStringOrNil([self entityName]), channelCount, @"1");
	return nil;
}


#ifndef NDEBUG
- (void) performStage:(SEL)stage
{
	// Ensure that we aren’t recursing.
	if (_stagesInProgress.count(stage) != 0)
	{
		OOLogERR(@"material.synthesis.error.recursion", @"Shader synthesis recursion for stage %s.", OOSelectorName(stage));
		[OOException raise:OOInternalInconsistencyException format:"stage recursion"];
	}
	
	_stagesInProgress.insert(stage);
	
	[self performSelector:stage];
	
	_stagesInProgress.erase(stage);
}
#endif


- (void) createTemporaries
{
	_attributes = [[NSMutableString alloc] init];
	_varyings = [[NSMutableString alloc] init];
	_vertexUniforms = [[NSMutableString alloc] init];
	_fragmentUniforms = [[NSMutableString alloc] init];
	_vertexHelpers = [[NSMutableString alloc] init];
	_fragmentHelpers = [[NSMutableString alloc] init];
	_vertexBody = [[NSMutableString alloc] init];
	_fragmentPreTextures = [[NSMutableString alloc] init];
	_fragmentTextureLookups = [[NSMutableString alloc] init];
	_fragmentBody = [[NSMutableString alloc] init];
	
	_textures = [[NSMutableArray alloc] init];
	_texturesByName = [[NSMutableDictionary alloc] init];
	_textureIDs = [[NSMutableDictionary alloc] init];
	_sampledTextures.clear();
	
	_uniformBindingNames = [[NSMutableDictionary alloc] init];
	
#ifndef NDEBUG
	_stagesInProgress.clear();
#endif
}


- (void) destroyTemporaries
{
	DESTROY(_attributes);
	DESTROY(_varyings);
	DESTROY(_vertexUniforms);
	DESTROY(_fragmentUniforms);
	DESTROY(_vertexHelpers);
	DESTROY(_fragmentHelpers);
	DESTROY(_vertexBody);
	DESTROY(_fragmentPreTextures);
	DESTROY(_fragmentTextureLookups);
	DESTROY(_fragmentBody);
	
	DESTROY(_texturesByName);
	DESTROY(_textureIDs);
	_sampledTextures.clear();
	
	DESTROY(_uniformBindingNames);
	
#ifndef NDEBUG
	_stagesInProgress.clear();
#endif
}


// MARK: - Synthesis stages

- (void) writeTextureCoordRead
{
	[self addVarying:@"vTexCoords" ofType:@"vec2"];
	[_vertexBody appendString:@"\tvTexCoords = gl_MultiTexCoord0.st;\n\t\n"];
	
	BOOL haveTexCoords = NO;
	oo::PList parallaxMap = cxx_OOMaterialParallaxMapSpecifier(_configuration);
	
	if (!parallaxMap.isNull())
	{
		float parallaxScale = cxx_OOMaterialParallaxScale(_configuration);
		if (parallaxScale != 0.0f)
		{
			/*
				We can’t call -getSampleName:... here because the standard
				texture loading mechanism has to occur after determining
				texture coordinates (duh).
			*/
			NSString *swizzle = GetExtractMode(oo::ObjectFromPList(parallaxMap)) ?: (NSString *)@"a";
			NSUInteger channelCount = [swizzle length];
			if (channelCount == 1)
			{
				haveTexCoords = YES;
				
				REQUIRE_STAGE(writeEyeVector);
				
				[_fragmentPreTextures appendString:@"\t// Parallax mapping\n"];
				
				NSUInteger texID = [self assignIDForTexture:oo::ObjectFromPList(parallaxMap)];
				[_fragmentPreTextures appendFormat:@"\tfloat parallax = texture2D(uTexture%zu, vTexCoords).%@;\n", texID, swizzle];
				
				if (parallaxScale != 1.0f)
				{
					[_fragmentPreTextures appendFormat:@"\tparallax *= %@;  // Parallax scale\n", FormatFloat(parallaxScale)];
				}
				
				float parallaxBias = cxx_OOMaterialParallaxBias(_configuration);
				if (parallaxBias != 0.0)
				{
					[_fragmentPreTextures appendFormat:@"\tparallax += %@;  // Parallax bias\n", FormatFloat(parallaxBias)];
				}
				
				[_fragmentPreTextures appendString:@"\tvec2 texCoords = vTexCoords - parallax * eyeVector.xy * vec2(1.0, -1.0);\n"];
			}
			else
			{
				OOLogWARN(@"material.synthesis.warning.extractionMismatch", @"The %@ map for material \"%@\" of \"%@\" specifies %zu channels to extract, but only %@ may be used.", @"parallax", oo::NSStringOrNil([self materialKey]), oo::NSStringOrNil([self entityName]), channelCount, @"1");
			}
		}
	}
	
	if (!haveTexCoords)
	{
		[_fragmentPreTextures appendString:@"\tvec2 texCoords = vTexCoords;\n"];
	}
}


- (void) writeDiffuseColorTermIfNeeded
{
	oo::PList			diffuseMap = cxx_OOMaterialDiffuseMapSpecifier(_configuration, [self materialKey]);
	OOColor				*diffuseColor = cxx_OOMaterialDiffuseColor(_configuration) ?: [OOColor whiteColor];
	
	if ([diffuseColor isBlack])  return;
	_usesDiffuseTerm = YES;
	
	BOOL haveDiffuseColor = NO;
	if (!diffuseMap.isNull())
	{
		NSString *readInstr = [self readRGBForTextureSpec:oo::ObjectFromPList(diffuseMap) mapName:@"diffuse"];
		if (EXPECT_NOT(readInstr == nil))
		{
			[_fragmentBody appendString:@"\t// INVALID EXTRACTION KEY\n\t\n"];
		}
		else
		{
			[_fragmentBody appendFormat:@"\tvec3 diffuseColor = %@;\n", readInstr];
			 haveDiffuseColor = YES;
		}
	}
	
	if (!haveDiffuseColor || ![diffuseColor isWhite])
	{
		float rgba[4];
		[diffuseColor getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
		NSString *format = nil;
		if (haveDiffuseColor)
		{
			format = @"\tdiffuseColor *= vec3(%@, %@, %@);\n";
		}
		else
		{
			format = @"\tconst vec3 diffuseColor = vec3(%@, %@, %@);\n";
			haveDiffuseColor = YES;
		}
		[_fragmentBody appendFormat:format, FormatFloat(rgba[0]), FormatFloat(rgba[1]), FormatFloat(rgba[2])];
	}
	
	(void) haveDiffuseColor;
	[_fragmentBody appendString:@"\t\n"];
}


- (void) writeDiffuseColorTerm
{
	REQUIRE_STAGE(writeDiffuseColorTermIfNeeded);
	
	if (!_usesDiffuseTerm)
	{
		[_fragmentBody appendString:@"\tconst vec3 diffuseColor = vec3(0.0);  // Diffuse colour is black.\n\t\n"];
	}
}


- (void) writeDiffuseLighting
{
	REQUIRE_STAGE(writeDiffuseColorTermIfNeeded);
	if (!_usesDiffuseTerm)  return;
	
	REQUIRE_STAGE(writeTotalColor);
	REQUIRE_STAGE(writeVertexPosition);
	REQUIRE_STAGE(writeNormalIfNeeded);
	REQUIRE_STAGE(writeLightVector);
	
	// FIXME: currently uncoloured diffuse and ambient lighting.
	NSString *normalDotLight = _constZNormal ? @"lightVector.z" : @"dot(normal, lightVector)";
	
	[_fragmentBody appendFormat:
	@"\t// Diffuse (Lambertian) and ambient lighting\n"
	 "\tvec3 diffuseLight = (gl_LightSource[1].diffuse * max(0.0, %@) + gl_LightModel.ambient).rgb;\n\t\n",
	 normalDotLight];
	
	_haveDiffuseLight = YES;
}


- (void) writeLightVector
{
	REQUIRE_STAGE(writeVertexPosition);
	REQUIRE_STAGE(writeNormalIfNeeded);
	
	[self addVarying:@"vLightVector" ofType:@"vec3"];
	
	[_vertexBody appendString:
	 @"\tvec3 lightVector = gl_LightSource[1].position.xyz;\n"
	  "\tvLightVector = lightVector * TBN;\n\t\n"];
	[_fragmentBody appendFormat:@"\tvec3 lightVector = normalize(vLightVector);\n\t\n"];
}


- (void) writeEyeVector
{
	REQUIRE_STAGE(writeVertexPosition);
	REQUIRE_STAGE(writeVertexTangentBasis);
	
	[self addVarying:@"vEyeVector" ofType:@"vec3"];
	
	[_vertexBody appendString:@"\tvEyeVector = position.xyz * TBN;\n\t\n"];
	[_fragmentPreTextures appendString:@"\tvec3 eyeVector = normalize(vEyeVector);\n\t\n"];
}


- (void) writeVertexTangentBasis
{
	[self addAttribute:@"tangent" ofType:@"vec3"];
	
	[_vertexBody appendString:
	 @"\t// Build tangent space basis\n"
	  "\tvec3 n = gl_NormalMatrix * gl_Normal;\n"
	  "\tvec3 t = gl_NormalMatrix * tangent;\n"
	  "\tvec3 b = cross(n, t);\n"
	  "\tmat3 TBN = mat3(t, b, n);\n\t\n"];
}


- (void) writeNormalIfNeeded
{
	REQUIRE_STAGE(writeVertexPosition);
	REQUIRE_STAGE(writeVertexTangentBasis);
	
	oo::PList normalMap = cxx_OOMaterialNormalMapSpecifier(_configuration);
	if (normalMap.isNull())
	{
		// FIXME: this stuff should be handled in OOMaterialSpecifier.m when synthesizer takes over the world. -- Ahruman 2012-02-08
		normalMap = cxx_OOMaterialNormalAndParallaxMapSpecifier(_configuration);
	}
	if (!normalMap.isNull())
	{
		NSString *sample, *swizzle;
		[self getSampleName:&sample andSwizzleOp:&swizzle forTextureSpec:oo::ObjectFromPList(normalMap)];
		if (swizzle == nil)  swizzle = @"rgb";
		if ([swizzle length] == 3)
		{
			[_fragmentBody appendFormat:@"\tvec3 normal = normalize(%@.%@ - 0.5);\n\t\n", sample, swizzle];
			_usesNormalMap = YES;
			return;
		}
		else
		{
			OOLogWARN(@"material.synthesis.warning.extractionMismatch", @"The %@ map for material \"%@\" of \"%@\" specifies %zu channels to extract, but only %@ may be used.", @"normal", oo::NSStringOrNil([self materialKey]), oo::NSStringOrNil([self entityName]), [swizzle length], @"3");
		}
	}
	_constZNormal = YES;
}


- (void) writeNormal
{
	REQUIRE_STAGE(writeNormalIfNeeded);
	
	if (_constZNormal)
	{
		[_fragmentBody appendString:@"\tconst vec3 normal = vec3(0.0, 0.0, 1.0);\n\t\n"];
	}
}


- (void) writeSpecularLighting
{
	float specularExponent = cxx_OOMaterialSpecularExponent(_configuration);
	if (specularExponent <= 0)  return;
	
	oo::PList specularColorMap = cxx_OOMaterialSpecularColorMapSpecifier(_configuration);
	oo::PList specularExponentMap = cxx_OOMaterialSpecularExponentMapSpecifier(_configuration);
	float scaleFactor = 1.0f;
	
	if (!specularColorMap.isNull())
	{
		scaleFactor = specularColorMap.get<double>(cxx_kOOTextureSpecifierScaleFactorKey, 1.0f);
	}
	
	OOColor *specularColor = nil;
	if (specularColorMap.isNull())
	{
		specularColor = cxx_OOMaterialSpecularColor(_configuration);
	}
	else
	{
		specularColor = cxx_OOMaterialSpecularModulateColor(_configuration);
	}
	
	if ([specularColor isBlack])  return;
	
	BOOL modulateWithDiffuse = specularColorMap.get<bool>(cxx_kOOTextureSpecifierSelfColorKey);
	
	REQUIRE_STAGE(writeTotalColor);
	REQUIRE_STAGE(writeNormalIfNeeded);
	REQUIRE_STAGE(writeEyeVector);
	REQUIRE_STAGE(writeLightVector);
	if (modulateWithDiffuse)
	{
		REQUIRE_STAGE(writeDiffuseColorTerm);
	}
	
	[_fragmentBody appendString:@"\t// Specular (Blinn-Phong) lighting\n"];
	
	BOOL haveSpecularColor = NO;
	if (!specularColorMap.isNull())
	{
		NSString *readInstr = [self readRGBForTextureSpec:oo::ObjectFromPList(specularColorMap) mapName:@"specular colour"];
		if (EXPECT_NOT(readInstr == nil))
		{
			[_fragmentBody appendString:@"\t// INVALID EXTRACTION KEY\n\t\n"];
			return;
		}
		
		[_fragmentBody appendFormat:@"\tvec3 specularColor = %@;\n", readInstr];
		haveSpecularColor = YES;
	}
	
	if (!haveSpecularColor || ![specularColor isWhite])
	{
		float rgba[4];
		[specularColor getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
		
		NSString *comment = (scaleFactor == 1.0f) ? @"Constant colour" : @"Constant colour and scale factor";
		
		// Handle scale factor, colour, and colour alpha scaling as one multiply.
		scaleFactor *= rgba[3];
		rgba[0] *= scaleFactor;
		rgba[1] *= scaleFactor;
		rgba[2] *= scaleFactor;
		
		// Avoid reapplying scaleFactor below.
		scaleFactor = 1.0;
		
		NSString *format = nil;
		if (haveSpecularColor)
		{
			format = @"\tspecularColor *= vec3(%@, %@, %@);  // %@\n";
		}
		else
		{
			format = @"\tvec3 specularColor = vec3(%@, %@, %@);  // %@\n";
			haveSpecularColor = YES;
		}
		[_fragmentBody appendFormat:format, FormatFloat(rgba[0]), FormatFloat(rgba[1]), FormatFloat(rgba[2]), comment];
	}
	
	// Handle scale_factor if no constant colour.
	if (haveSpecularColor && scaleFactor != 1.0f)
	{
		[_fragmentBody appendFormat:@"\tspecularColor *= %@;  // Scale factor\n", FormatFloat(scaleFactor)];
	}
	
	// Handle self_color.
	if (modulateWithDiffuse)
	{
		[_fragmentBody appendString:@"\tspecularColor *= diffuseColor;  // Self-colouring\n"];
	}
	
	// Specular exponent.
	BOOL haveSpecularExponent = NO;
	if (!specularExponentMap.isNull())
	{
		NSString *readInstr = [self readOneChannelForTextureSpec:oo::ObjectFromPList(specularExponentMap) mapName:@"specular exponent"];
		if (EXPECT_NOT(readInstr == nil))
		{
			[_fragmentBody appendString:@"\t// INVALID EXTRACTION KEY\n\t\n"];
			return;
		}
		
		[_fragmentBody appendFormat:@"\tfloat specularExponent = %@ * %.1f;\n", readInstr, specularExponent];
		haveSpecularExponent = YES;
	}
	if (!haveSpecularExponent)
	{
		[_fragmentBody appendFormat:@"\tconst float specularExponent = %.1f;\n", specularExponent];
	}
	
	if (_usesNormalMap)
	{
		[_fragmentBody appendFormat:@"\tvec3 reflection = reflect(lightVector, normal);\n"];
	}
	else
	{
		/*	reflect(I, N) is defined as I - 2 * dot(N, I) * N
			If N is (0,0,1), this becomes (I.x,I.y,-I.z).
		*/
		[_fragmentBody appendFormat:@"\tvec3 reflection = vec3(lightVector.x, lightVector.y, -lightVector.z);  // Equivalent to reflect(lightVector, normal) since normal is known to be (0, 0, 1) in tangent space.\n"];
	}
	
	[_fragmentBody appendFormat:
	@"\tfloat specIntensity = dot(reflection, eyeVector);\n"
	 "\tspecIntensity = pow(max(0.0, specIntensity), specularExponent);\n"
	 "\ttotalColor += specIntensity * specularColor * gl_LightSource[1].specular.rgb;\n\t\n"];
}


- (void) writeLightMaps
{
	const oo::PList *lightMaps = _configuration.get<oo::PList::Array>(cxx_kOOMaterialLightMapsName);
	NSUInteger idx, count = (lightMaps != nullptr) ? lightMaps->count() : 0;
	if (count == 0)  return;
	
	REQUIRE_STAGE(writeTotalColor);
	
	// Check if we need the diffuse colour term.
	for (idx = 0; idx < count; idx++)
	{
		const oo::PList *lightMapSpec = lightMaps->at<oo::PList::Dict>(idx);
		if (lightMapSpec != nullptr && lightMapSpec->get<bool>(cxx_kOOTextureSpecifierIlluminationModeKey))
		{
			REQUIRE_STAGE(writeDiffuseColorTerm);
			REQUIRE_STAGE(writeDiffuseLighting);
			break;
		}
	}
	
	[_fragmentBody appendString:@"\tvec3 lightMapColor;\n"];
	
	const oo::PList notADictionary;	// a light map entry that is not a dictionary reads as nil
	for (idx = 0; idx < count; idx++)
	{
		const oo::PList	*entry = lightMaps->at<oo::PList::Dict>(idx);
		const oo::PList	&lightMapSpec = (entry != nullptr) ? *entry : notADictionary;
		oo::PList		textureSpec = cxx_OOTextureSpecFromObject(lightMapSpec, std::nullopt);
		const oo::PList	*color = lightMapSpec.get<oo::PList::Array>(cxx_kOOTextureSpecifierModulateColorKey);
		float			rgba[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
		BOOL			isIllumination = lightMapSpec.get<bool>(cxx_kOOTextureSpecifierIlluminationModeKey);
		
		if (EXPECT_NOT(color == nullptr && textureSpec.isNull()))
		{
			[_fragmentBody appendString:@"\t// Light map with neither colour nor texture has no effect.\n\t\n"];
			continue;
		}
		
		if (color != nullptr)
		{
			NSUInteger idx, count = color->count();
			if (count > 4)  count = 4;
			for (idx = 0; idx < count; idx++)
			{
				rgba[idx] = color->at<double>(idx);
			}
			rgba[0] *= rgba[3]; rgba[1] *= rgba[3]; rgba[2] *= rgba[3];
		}
		
		if (EXPECT_NOT((rgba[0] == 0.0f && rgba[1] == 0.0f && rgba[2] == 0.0f) ||
					   (!_usesDiffuseTerm && isIllumination)))
		{
			[_fragmentBody appendString:@"\t// Light map tinted black has no effect.\n\t\n"];
			continue;
		}
		
		if (!textureSpec.isNull())
		{
			NSString *readInstr = [self readRGBForTextureSpec:oo::ObjectFromPList(textureSpec) mapName:@"light"];
			if (EXPECT_NOT(readInstr == nil))
			{
				[_fragmentBody appendString:@"\t// INVALID EXTRACTION KEY\n\n"];
				continue;
			}
			
			[_fragmentBody appendFormat:@"\tlightMapColor = %@;\n", readInstr];
			
			if (rgba[0] != 1.0f || rgba[1] != 1.0f || rgba[2] != 1.0f)
			{
				[_fragmentBody appendFormat:@"\tlightMapColor *= vec3(%@, %@, %@);\n", FormatFloat(rgba[0]), FormatFloat(rgba[1]), FormatFloat(rgba[2])];
			}
		}
		else
		{
			[_fragmentBody appendFormat:@"\tlightMapColor = vec3(%@, %@, %@);\n", FormatFloat(rgba[0]), FormatFloat(rgba[1]), FormatFloat(rgba[2])];
		}
		
		const oo::PList *binding = textureSpec.get<oo::PList::Dict>(cxx_kOOTextureSpecifierBindingKey);
		if (binding != nullptr)
		{
			NSString *bindingName = oo::NSStringFrom(binding->get<std::string>("binding"));
			NSDictionary *typeDict = oo::PListView([ResourceManager shaderBindingTypesDictionary]).get<NSDictionary *>(@"player");	// FIXME: select appropriate binding subset.
			NSString *bindingType = oo::PListView(typeDict).get<NSString *>(bindingName);
			NSString *glslType = nil;
			NSString *swizzle = @"";
			
			if ([bindingType isEqualToString:@"float"])
			{
				glslType = @"float";
			}
			else if ([bindingType isEqualToString:@"vector"])
			{
				glslType = @"vec3";
			}
			else if ([bindingType isEqualToString:@"color"])
			{
				glslType = @"vec4";
				swizzle = @".rgb";
			}
			
			if (glslType != nil)
			{
				NSString *uniformName = [self defineBindingUniform:oo::ObjectFromPList(*binding) ofType:bindingType];
				[_fragmentBody appendFormat:@"\tlightMapColor *= %@%@;\n", uniformName, swizzle];
			}
			else
			{
				if (bindingType == nil)
				{
					OOLogERR(@"material.binding.error.unknown", @"Cannot bind light map to unknown attribute \"%@\".", bindingName);
				}
				else
				{
					OOLogERR(@"material.binding.error.badType", @"Cannot bind light map to attribute \"%@\" of type %@.", bindingName, bindingType);
				}
				[_fragmentBody appendString:@"\tlightMapColor = vec3(0.0);  // Bad binding, see log.\n"];
			}
		}
		
		if (!isIllumination)
		{
			[_fragmentBody appendString:@"\ttotalColor += lightMapColor;\n\t\n"];
		}
		else
		{
			[_fragmentBody appendString:@"\tdiffuseLight += lightMapColor;\n\t\n"];
		}
	}
}


- (void) writeVertexPosition
{
	[_vertexBody appendString:
	@"\tvec4 position = gl_ModelViewMatrix * gl_Vertex;\n"
	 "\tgl_Position = gl_ProjectionMatrix * position;\n\t\n"];
}


- (void) writeTotalColor
{
	[_fragmentPreTextures appendString:@"\tvec3 totalColor = vec3(0.0);\n\t\n"];
}


- (void) writeFinalColorComposite
{
	REQUIRE_STAGE(writeTotalColor);	// Needed even if none of the following stages does anything.
	REQUIRE_STAGE(writeDiffuseLighting);
	REQUIRE_STAGE(writeSpecularLighting);
	REQUIRE_STAGE(writeLightMaps);
	
	if (_haveDiffuseLight)
	{
		[_fragmentBody appendString:@"\ttotalColor += diffuseColor * diffuseLight;\n"];
	}
	
	[_fragmentBody appendString:@"\tgl_FragColor = vec4(totalColor, 1.0);\n\t\n"];
}

@end

namespace {

// A texture specifier naming just a file: [NSDictionary dictionaryWithObject:name forKey:kOOTextureSpecifierNameKey].
oo::PList NameSpecifier(const std::string &name)
{
	return oo::PList(oo::PList::Dict{ { cxx_kOOTextureSpecifierNameKey, oo::PList(name) } });
}


// A string becomes a name specifier, a dictionary is kept, anything else (or no value) is nil.
oo::PList StringOrDictionarySpecifier(const oo::PList *texSpec)
{
	if (texSpec == nullptr)  return oo::PList();
	if (const std::string *name = texSpec->getIf<std::string>())  return NameSpecifier(*name);
	if (texSpec->isDict())  return *texSpec;
	return oo::PList();
}


// -dictionaryByAddingObject:object forKey:key on a dictionary specifier.
oo::PList AddingValue(oo::PList specifier, const char *key, oo::PList value)
{
	if (oo::PList::Dict *dict = specifier.getIf<oo::PList::Dict>())  (*dict)[key] = std::move(value);
	return specifier;
}


// +[OOColor colorWithDescription:] of the value for key (nil if there is none).
OOColor *ColorIn(const oo::PList &spec, const char *key)
{
	const oo::PList *value = spec.find(key);
	return [OOColor colorWithDescription:(value != nullptr) ? oo::ObjectFromPList(*value) : nil];
}


// -[OOColor normalizedArray]: four +numberWithFloat: components.
oo::PList NormalizedArray(OOColor *color)
{
	oo::PList::Array result;
	for (float component : [color cxx_normalizedArray])  result.push_back(oo::PList::singleReal(component));
	return oo::PList(std::move(result));
}


/*
	Convert any legacy properties and simplified forms in a material specifier
	to the standard form.
	
	FIXME: this should be done up front in OOShipRegistry. When doing that, it
	also need to be done when materials are set on the fly through JS,
*/
oo::PList CanonicalizeMaterialSpecifier(const oo::PList &spec, const std::optional<std::string> &materialKey)
{
	oo::PList::Dict			result;
	OOColor					*col = nil;
	oo::PList				texSpec;
	
	// Colours.
	col = ColorIn(spec, cxx_kOOMaterialDiffuseColorName);
	if (col == nil)  col = ColorIn(spec, cxx_kOOMaterialDiffuseColorLegacyName);
	if (col != nil)  result[cxx_kOOMaterialDiffuseColorName] = NormalizedArray(col);
	
	col = ColorIn(spec, cxx_kOOMaterialAmbientColorName);
	if (col == nil)  col = ColorIn(spec, cxx_kOOMaterialAmbientColorLegacyName);
	if (col != nil)  result[cxx_kOOMaterialAmbientColorName] = NormalizedArray(col);
	
	col = ColorIn(spec, cxx_kOOMaterialSpecularColorName);
	if (col == nil)  col = ColorIn(spec, cxx_kOOMaterialSpecularColorLegacyName);
	if (col != nil)  result[cxx_kOOMaterialSpecularColorName] = NormalizedArray(col);
	
	col = ColorIn(spec, cxx_kOOMaterialSpecularModulateColorName);
	if (col != nil)  result[cxx_kOOMaterialSpecularModulateColorName] = NormalizedArray(col);
	
	col = ColorIn(spec, cxx_kOOMaterialEmissionColorName);
	if (col == nil)  col = ColorIn(spec, cxx_kOOMaterialEmissionColorLegacyName);
	if (col != nil)  result[cxx_kOOMaterialEmissionColorName] = NormalizedArray(col);
	
	// Diffuse map.
	const oo::PList *diffuseSpec = spec.find(cxx_kOOMaterialDiffuseMapName);
	if (diffuseSpec != nullptr && diffuseSpec->isString())
	{
		const std::string &name = *diffuseSpec->getIf<std::string>();
		texSpec = name.empty() ? *diffuseSpec : NameSpecifier(name);
	}
	else if (diffuseSpec != nullptr && diffuseSpec->isDict())
	{
		/*	Special case for diffuse map: no name is changed to
			name = materialKey, while name = "" is changed to no name.
		*/
		texSpec = *diffuseSpec;
		const oo::PList *name = diffuseSpec->find(cxx_kOOTextureSpecifierNameKey);
		if (name == nullptr)
		{
			if (materialKey.has_value())  texSpec = AddingValue(texSpec, cxx_kOOTextureSpecifierNameKey, oo::PList(*materialKey));
		}
		else if (name->isString() && name->getIf<std::string>()->empty())
		{
			texSpec.getIf<oo::PList::Dict>()->erase(cxx_kOOTextureSpecifierNameKey);
		}
	}
	else
	{
		// Special case for unspecified diffuse map. (The one caller always has a material key.)
		texSpec = NameSpecifier(materialKey.value_or(std::string()));
	}
	result[cxx_kOOMaterialDiffuseMapName] = texSpec;
	
	// Specular maps.
	{
		BOOL haveNewSpecular = NO;
		texSpec = StringOrDictionarySpecifier(spec.find(cxx_kOOMaterialSpecularColorMapName));
		if (!texSpec.isNull())
		{
			haveNewSpecular = YES;
			result[cxx_kOOMaterialSpecularColorMapName] = texSpec;
		}
		
		texSpec = StringOrDictionarySpecifier(spec.find(cxx_kOOMaterialSpecularExponentMapName));
		if (!texSpec.isNull())
		{
			haveNewSpecular = YES;
			result[cxx_kOOMaterialSpecularExponentMapName] = texSpec;
		}
		
		if (!haveNewSpecular)
		{
			// Fall back to legacy combined specular map if defined.
			texSpec = StringOrDictionarySpecifier(spec.find(cxx_kOOMaterialCombinedSpecularMapName));
			if (!texSpec.isNull())
			{
				result[cxx_kOOMaterialSpecularColorMapName] = texSpec;
				texSpec = AddingValue(texSpec, cxx_kOOTextureSpecifierSwizzleKey, oo::PList("a"));
				result[cxx_kOOMaterialSpecularExponentMapName] = texSpec;
			}
		}
	}
	
	// Normal and parallax maps.
	{
		BOOL haveParallax = NO;
		BOOL haveNewNormal = NO;
		texSpec = StringOrDictionarySpecifier(spec.find(cxx_kOOMaterialNormalMapName));
		if (!texSpec.isNull())
		{
			haveNewNormal = YES;
			result[cxx_kOOMaterialNormalMapName] = texSpec;
		}
		
		texSpec = StringOrDictionarySpecifier(spec.find(cxx_kOOMaterialParallaxMapName));
		if (!texSpec.isNull())
		{
			haveNewNormal = YES;
			haveParallax = YES;
			result[cxx_kOOMaterialParallaxMapName] = texSpec;
		}
		
		if (!haveNewNormal)
		{
			// Fall back to legacy combined normal and parallax map if defined.
			texSpec = StringOrDictionarySpecifier(spec.find(cxx_kOOMaterialNormalAndParallaxMapName));
			if (!texSpec.isNull())
			{
				haveParallax = YES;
				result[cxx_kOOMaterialNormalMapName] = texSpec;
				texSpec = AddingValue(texSpec, cxx_kOOTextureSpecifierSwizzleKey, oo::PList("a"));
				result[cxx_kOOMaterialParallaxMapName] = texSpec;
			}
		}
		
		// Additional parallax parameters (-oo_setFloat:forKey: stores a double).
		if (haveParallax)
		{
			float parallaxScale = spec.get<float>(cxx_kOOMaterialParallaxScaleName, kOOMaterialDefaultParallaxScale);
			result[cxx_kOOMaterialParallaxScaleName] = oo::PList(static_cast<double>(parallaxScale));
			
			float parallaxBias = spec.get<float>(cxx_kOOMaterialParallaxBiasName);
			result[cxx_kOOMaterialParallaxBiasName] = oo::PList(static_cast<double>(parallaxBias));
		}
	}
	
	// Light maps.
	{
		oo::PList::Array lightMaps;
		oo::PList::Array lightMapSpecs;
		if (const oo::PList *value = spec.find(cxx_kOOMaterialLightMapsName))
		{
			if (const oo::PList::Array *array = value->getIf<oo::PList::Array>())  lightMapSpecs = *array;
			else  lightMapSpecs.push_back(*value);
		}
		
		for (const oo::PList &entry : lightMapSpecs)
		{
			oo::PList lmSpec;
			if (const std::string *name = entry.getIf<std::string>())
			{
				lmSpec = NameSpecifier(*name);
			}
			else if (entry.isDict())
			{
				lmSpec = entry;
			}
			else
			{
				continue;
			}
			oo::PList::Dict &lmDict = *lmSpec.getIf<oo::PList::Dict>();
			
			auto modulateColor = lmDict.find(cxx_kOOTextureSpecifierModulateColorKey);
			if (modulateColor != lmDict.end() && !modulateColor->second.isArray())
			{
				// Don't convert arrays here, because we specifically don't want the behaviour of treating numbers greater than 1 as 0..255 components.
				col = [OOColor colorWithDescription:oo::ObjectFromPList(modulateColor->second)];
				// A description that is no colour leaves no colour (upstream set nil, which Foundation refuses).
				if (col != nil)  modulateColor->second = NormalizedArray(col);
				else  lmDict.erase(modulateColor);
			}
			
			auto binding = lmDict.find(cxx_kOOTextureSpecifierBindingKey);
			if (binding != lmDict.end())
			{
				if (const std::string *bindingName = binding->second.getIf<std::string>())
				{
					oo::PList expandedBinding(oo::PList::Dict{ { "type", oo::PList("binding") }, { "binding", oo::PList(*bindingName) } });
					binding->second = std::move(expandedBinding);
				}
				else if (!binding->second.isDict() || binding->second.get<std::string>("binding").empty())
				{
					lmDict.erase(binding);
				}
			}
			
			lightMaps.push_back(std::move(lmSpec));
		}
		
		if (lightMaps.empty())
		{
			// If light_map isn't use, handle legacy emission_map, illumination_map and emission_and_illumination_map.
			const oo::PList *emissionValue = spec.find(cxx_kOOMaterialEmissionMapName);
			const oo::PList *illuminationValue = spec.find(cxx_kOOMaterialIlluminationMapName);
			oo::PList emissionSpec = (emissionValue != nullptr) ? *emissionValue : oo::PList();
			oo::PList illuminationSpec = (illuminationValue != nullptr) ? *illuminationValue : oo::PList();
			
			if (emissionSpec.isNull() && illuminationSpec.isNull())
			{
				// Redundantish string check required because we want to modify this as a dictionary to make illuminationSpec.
				emissionSpec = StringOrDictionarySpecifier(spec.find(cxx_kOOMaterialEmissionAndIlluminationMapName));
				
				if (!emissionSpec.isNull())
				{
					illuminationSpec = AddingValue(emissionSpec, cxx_kOOTextureSpecifierSwizzleKey, oo::PList("a"));
				}
			}
			
			if (!emissionSpec.isNull())
			{
				if (const std::string *name = emissionSpec.getIf<std::string>())
				{
					emissionSpec = NameSpecifier(*name);
				}
				if (emissionSpec.isDict())
				{
					col = ColorIn(spec, cxx_kOOMaterialEmissionModulateColorName);
					if (col != nil)  emissionSpec = AddingValue(emissionSpec, cxx_kOOTextureSpecifierModulateColorKey, NormalizedArray(col));
					
					lightMaps.push_back(emissionSpec);
				}
			}
			
			if (!illuminationSpec.isNull())
			{
				if (const std::string *name = illuminationSpec.getIf<std::string>())
				{
					illuminationSpec = NameSpecifier(*name);
				}
				if (illuminationSpec.isDict())
				{
					col = ColorIn(spec, cxx_kOOMaterialIlluminationModulateColorName);
					if (col != nil)  illuminationSpec = AddingValue(illuminationSpec, cxx_kOOTextureSpecifierModulateColorKey, NormalizedArray(col));
					
					illuminationSpec = AddingValue(illuminationSpec, cxx_kOOTextureSpecifierIlluminationModeKey, oo::PList(true));
					
					lightMaps.push_back(illuminationSpec);
				}
			}
		}
		
		result[cxx_kOOMaterialLightMapsName] = oo::PList(std::move(lightMaps));
	}
	
	oo::PList canonical(std::move(result));
	OOLog(@"material.canonicalForm", @"Canonicalized material %@:\nORIGINAL:\n%@\n\n@CANONICAL:\n%@", oo::NSStringOrNil(materialKey), oo::ObjectFromPList(spec), oo::ObjectFromPList(canonical));
	
	return canonical;
}

}	// namespace


static NSString *FormatFloat(double value)
{
	long long intValue = value;
	if (value == intValue)
	{
		return [NSString stringWithFormat:@"%lli.0", intValue];
	}
	else
	{
		return [NSString stringWithFormat:@"%g", value];
	}
}
