/*

GuiDisplayGen+FoundationBridge.mm

TRANSITIONAL: see GuiDisplayGen+FoundationBridge.h. Each method forwards to its cxx_ counterpart
and converts the result exactly as the old method produced it (nil for nil).

*/

#import "GuiDisplayGen.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"


@implementation GuiDisplayGen (OOFoundationBridge)

// Chunk 1 (oo-3rb.92).

- (id) initWithPixelSize:(NSSize)gui_size
				 columns:(int)gui_cols
					rows:(int)gui_rows
			   rowHeight:(int)gui_row_height
				rowStart:(int)gui_row_start
				   title:(NSString*)gui_title
{
	return [self cxx_initWithPixelSize:gui_size columns:gui_cols rows:gui_rows rowHeight:gui_row_height rowStart:gui_row_start title:oo::OptionalString(gui_title)];
}


- (void) resizeWithPixelSize:(NSSize)gui_size
					 columns:(int)gui_cols
						rows:(int)gui_rows
				   rowHeight:(int)gui_row_height
					rowStart:(int)gui_row_start
					   title:(NSString*) gui_title
{
	[self cxx_resizeWithPixelSize:gui_size columns:gui_cols rows:gui_rows rowHeight:gui_row_height rowStart:gui_row_start title:oo::OptionalString(gui_title)];
}


- (void) resizeTo:(NSSize)gui_size
  characterHeight:(int)csize
			title:(NSString*)gui_title
{
	[self cxx_resizeTo:gui_size characterHeight:csize title:oo::OptionalString(gui_title)];
}


- (NSString *) keyForRow:(OOGUIRow)row
{
	return oo::NSStringOrNil([self cxx_keyForRow:row]);
}


- (OOGUIRow) rowForKey:(NSString*)key
{
	return [self cxx_rowForKey:oo::OptionalString(key)];
}


- (NSString *) selectedRowText
{
	return oo::NSStringOrNil([self cxx_selectedRowText]);
}


- (NSString *) selectedRowKey
{
	return oo::NSStringOrNil([self cxx_selectedRowKey]);
}


- (void) setKey:(NSString *)str forRow:(OOGUIRow)row
{
	[self cxx_setKey:oo::StdString(str) forRow:row];
}


- (void) setText:(NSString *)str forRow:(OOGUIRow)row
{
	[self cxx_setText:oo::StdString(str) forRow:row];
}


- (void) setText:(NSString *)str forRow:(OOGUIRow)row align:(OOGUIAlignment)alignment
{
	[self cxx_setText:oo::OptionalString(str) forRow:row align:alignment];
}


- (void) setArray:(NSArray *)arr forRow:(OOGUIRow)row
{
	[self cxx_setArray:oo::StringsFrom(arr) forRow:row];
}

@end
