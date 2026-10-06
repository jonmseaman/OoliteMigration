/*

OOALSoundMixer.h

Class responsible for managing and mixing sound channels. This class is an
implementation detail. Do not use it directly; use an OOSoundSource to play an
OOSound.

C++20 since bead oo-6g4z (proposed ADR-0056, the Audio module: amendment oo-2en; a singleton:
amendment oo-r7m0). Its Objective-C facade was deleted by bead oo-9ht.87: the sound sources, the
root sound and the OpenAL controller call OOSoundMixer::sharedMixer(), null-guarded.

OOALSound - OpenAL sound implementation for Oolite.
Copyright (C) 2006-2013 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
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

#ifndef OOALSOUNDMIXER_H
#define OOALSOUNDMIXER_H

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#import "OOALSoundChannel.h"	// complete: the mixer keeps oo::Ref<OOSoundChannel> members

#include "oofnd/Ref.hpp"


enum
{
	kMixerGeneralChannels		= 32
};


class OOSoundMixer : public oo::RefCounted
{
public:
	/*	Singleton accessor (amendment oo-r7m0 item 1): the one mixer, made on first use; borrowed.
		Null while sound cannot be set up, and then the next call asks again.
	*/
	static OOSoundMixer *sharedMixer();

	void update();

	// Only to be called at app shutdown, by OOOpenALController::shutdown(). (Declared here since
	// bead oo-r7m0: the declaration it resolved to was OOOpenALController's own -shutdown.)
	void shutdown();

	OOSoundChannel *popChannel();
	void pushChannel(OOSoundChannel *channel);

private:
	bool init();

	// _channels keeps each channel the mixer made, as it retained each before; the free list is
	// borrowed (C++ since bead oo-9ht.86 deleted the channel's facade).
	oo::Ref<OOSoundChannel>		_channels[kMixerGeneralChannels];
	OOSoundChannel				*_freeList = {};

	// (The Objective-C class's _maxChannels and _playMask, which nothing read or wrote, are not
	// kept: -Wunused-private-field.)

};

#endif	// OOALSOUNDMIXER_H
