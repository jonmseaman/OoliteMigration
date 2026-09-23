/*

GuiDisplayGen+FoundationBridge.h

TRANSITIONAL (proposed ADR-0043, "Transitional bridges"; made by bead oo-3rb.92, chunk 1 of the
GuiDisplayGen sweep oo-ol63, and extended only by its later chunks oo-3rb.93-.96). GuiDisplayGen's
Foundation-typed API as it was before its sweep, with the same selector names and types,
forwarding to the cxx_ API in GuiDisplayGen.h. It exists so that GuiDisplayGen's callers (13
files) compile unchanged; each caller moves to the cxx_ API in its own sweep bead. When
`git grep` finds no caller of anything declared here, the bridge bead deletes this file,
GuiDisplayGen+FoundationBridge.mm, its line in Core/meson.build and the #import at the end of
GuiDisplayGen.h. Never add to it outside the GuiDisplayGen chunks; never call it from migrated
code. oo-qps (the removal of gnustep-base) cannot compile while it exists.

Registry: src/oofnd/README.md, "Transitional bridges".

Copyright (C) 2004-2013 Giles C Williams and contributors (GuiDisplayGen.h)

*/

// Imported only from the end of GuiDisplayGen.h (which declares everything used here); never
// import it directly, and never import GuiDisplayGen.h from it (a cycle).
#ifndef GUIDISPLAYGEN_FOUNDATIONBRIDGE_H
#define GUIDISPLAYGEN_FOUNDATIONBRIDGE_H


@interface GuiDisplayGen (OOFoundationBridge)

// Chunk 1 (oo-3rb.92): row text and keys, title initialisers.
- (id) initWithPixelSize:(NSSize)gui_size
				 columns:(int)gui_cols 
					rows:(int)gui_rows 
			   rowHeight:(int)gui_row_height
				rowStart:(int)gui_row_start
				   title:(NSString*)gui_title;	// -> -cxx_initWithPixelSize:columns:rows:rowHeight:rowStart:title:

- (void) resizeWithPixelSize:(NSSize)gui_size
					 columns:(int)gui_cols
						rows:(int)gui_rows
				   rowHeight:(int)gui_row_height
					rowStart:(int)gui_row_start
					   title:(NSString*) gui_title;	// -> -cxx_resizeWithPixelSize:columns:rows:rowHeight:rowStart:title:
- (void) resizeTo:(NSSize)gui_size
  characterHeight:(int)csize
			title:(NSString*)gui_title;	// -> -cxx_resizeTo:characterHeight:title:

- (NSString *) keyForRow:(OOGUIRow)row;	// -> -cxx_keyForRow:
- (OOGUIRow) rowForKey:(NSString*)key;	// -> -cxx_rowForKey:
- (NSString *) selectedRowText;	// -> -cxx_selectedRowText
- (NSString *) selectedRowKey;	// -> -cxx_selectedRowKey

- (void) setKey:(NSString *)str forRow:(OOGUIRow)row;	// -> -cxx_setKey:forRow:
- (void) setText:(NSString *)str forRow:(OOGUIRow)row;	// -> -cxx_setText:forRow:
- (void) setText:(NSString *)str forRow:(OOGUIRow)row align:(OOGUIAlignment)alignment;	// -> -cxx_setText:forRow:align:

- (void) setArray:(NSArray *)arr forRow:(OOGUIRow)row;	// -> -cxx_setArray:forRow:

// Chunk 2 (oo-3rb.93): long text, reflow and item lists.
- (NSString *) reflowTextForMFD:(NSString *)input;	// -> -cxx_reflowTextForMFD:
- (OOGUIRow) addLongText:(NSString *)str
		   startingAtRow:(OOGUIRow)row
				   align:(OOGUIAlignment)alignment;	// -> -cxx_addLongText:startingAtRow:align:
- (void) printLongText:(NSString *)str
				 align:(OOGUIAlignment)alignment
				 color:(OOColor *)text_color
			  fadeTime:(float)text_fade
				   key:(NSString *)text_key
			addToArray:(NSMutableArray *)text_array;	// -> -cxx_printLongText:align:color:fadeTime:key:addToArray:
- (void) printLineNoScroll:(NSString *)str
					 align:(OOGUIAlignment)alignment
					 color:(OOColor *)text_color
				  fadeTime:(float)text_fade
					   key:(NSString *)text_key
				addToArray:(NSMutableArray *)text_array;	// -> -cxx_printLineNoScroll:align:color:fadeTime:key:addToArray:

- (void) insertItemsFromArray:(NSArray *)items
					 withKeys:(NSArray *)item_keys
					  intoRow:(OOGUIRow)row
						color:(OOColor *)text_color;	// -> -cxx_insertItemsFromArray:withKeys:intoRow:color:

- (NSArray *) getLastLines;	// -> -cxx_getLastLines

@end

#endif	// GUIDISPLAYGEN_FOUNDATIONBRIDGE_H
