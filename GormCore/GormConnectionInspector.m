/* GormInspectorsManager.m
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	1999
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2003,2005
 *
 * This file is part of GNUstep.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/NSNibConnector.h>
#include <InterfaceBuilder/IBInspector.h>

#include "GormPrivate.h"
#include "GormConnectionInspector.h"

@implementation GormConnectionInspector

- (id) init
{
  if ((self = [super init]) != nil)
    {
      if([NSBundle loadNibNamed: @"GormConnectionInspector" owner: self] == NO)
	{
	  NSLog(@"Couldn't load GormConnectionInsector");
	  return nil;
	}

      // Create the okay and revert buttons, programmatically, since we shouldn't 
      // add them to the view.  The wantsButtons handling code will do that.
      okButton = [[NSButton alloc] initWithFrame: NSMakeRect(0,0,80,20)];
      [okButton setAutoresizingMask: NSViewMinXMargin];
      [okButton setAction: @selector(ok:)];
      [okButton setTarget: self];
      [okButton setTitle: _(@"Connect")];
      [okButton setEnabled: NO];

      revertButton = [[NSButton alloc] initWithFrame: NSMakeRect(0,0,80,20)];
      [revertButton setAutoresizingMask: NSViewMaxXMargin];
      [revertButton setAction: @selector(revert:)];
      [revertButton setTarget: self];
      [revertButton setTitle: _(@"Revert")];
      [revertButton setEnabled: NO];      
    }
  return self;
}

- (void) awakeFromNib
{
  [newBrowser setDoubleAction: @selector(ok:)];
}

- (NSInteger) browser: (NSBrowser*)sender numberOfRowsInColumn: (NSInteger)column
{
  NSInteger		rows = 0;

  if (sender == newBrowser)
    {
      if (column == 0)
	{
	  rows = [outlets count];
	}
      else
	{
	  NSString	*name = [[sender selectedCellInColumn: 0] stringValue];

	  if ([name isEqual: @"target"])
	    {
	      rows = [actions count];
	    }
	}
    }
  else
    {
      rows = [connectors count];
    }
  return rows;
}

- (NSString*) browser: (NSBrowser*)sender titleOfColumn: (NSInteger)column
{
  if (sender == newBrowser)
    {
      if (column == 0)
	{
	  return @"Outlets";
	}
      else
	{
	  NSString	*name = [[sender selectedCellInColumn: 0] stringValue];

	  if ([name isEqual: @"target"])
	    {
	      return @"Actions";
	    }
	  else
	    {
	      return @"";
	    }
	}
    }
  else
    {
      return @"Connections";
    }
}

- (void) _selectAction: (NSString *)action
{
  /*
   * Ensure that the actions are displayed in column one,
   * and select the action for the current connection (if any).
   */
  [newBrowser reloadColumn: 1];
  if (action != nil)
    {
      [newBrowser selectRow: [actions indexOfObject: action]
		  inColumn: 1];
    }
}

- (void) _internalCall: (NSBrowser*)sender
{
  unsigned	numConnectors = [connectors count];
  unsigned	index;
  NSBrowserCell	*cell = [sender selectedCell];
  NSString	*title = [cell stringValue];
  NSInteger		col = [sender selectedColumn];

  if (sender == newBrowser)
    {
      if (col == 0)
	{
	  if ([title isEqual: @"target"])
	    {
	      id	con = nil;

	      for (index = 0; index < numConnectors; index++)
		{
		  con = [connectors objectAtIndex: index];
		  if ([con isKindOfClass: [NSNibControlConnector class]] == YES)
		    {
		      RELEASE(actions);
		      actions = RETAIN([[(id<Gorm>)NSApp classManager]
			allActionsForObject: [con destination]]);
		      break;
		    }
		  else
		    {
		      con = nil;
		    }
		}

	      if (con == nil) // && [actions containsObject: [currentConnector label]] == NO) 
		{
		  RELEASE(actions);
		  actions = RETAIN([[(id<Gorm>)NSApp classManager]
		    allActionsForObject: [NSApp connectDestination]]);
		  if ([actions count] > 0)
		    {
		      con = [[NSNibControlConnector alloc] init];
		      [con setSource: object];
		      [con setDestination: [NSApp connectDestination]];
		      [con setLabel: [actions objectAtIndex: 0]];
		      AUTORELEASE(con);
		    }
		}

	      // if we changed the current connector, update to the new one...
  	      if (currentConnector != con)
  		{
  		  ASSIGN(currentConnector, con);
  		}

	      /*
	       * Ensure that the actions are displayed in column one,
	       * and select the action for the current connection (if any).
	       */
	      [self _selectAction: [con label]];
	    }
	  else
	    {
	      BOOL	found = NO;

	      /*
	       * See if there already exists a connector for this outlet.
	       */
	      for (index = 0; index < numConnectors; index++)
		{
		  id	con = [connectors objectAtIndex: index];

		  if ([con label] == nil || [[con label] isEqual: title] == YES)
		    {
		      ASSIGN(currentConnector, con);
		      found = YES;
		      break;
		    }
		}
	      /*
	       * if there was no connector, make one.
	       */
	      if (found == NO)
		{
		  RELEASE(currentConnector);
		  currentConnector = [[NSNibOutletConnector alloc] init];
		  [currentConnector setSource: object];
		  [currentConnector setDestination: [NSApp connectDestination]];
		  [currentConnector setLabel: title];
		}
	    }
	  /*
	   * Update the bottom browser.
	   */
	  [oldBrowser loadColumnZero];
	  [oldBrowser selectRow: index inColumn: 0];
	  [NSApp displayConnectionBetween: object
				      and: [currentConnector destination]];
	}
      else
	{
	  BOOL	found = NO;

	  for (index = 0; index < numConnectors; index++)
	    {
	      id	con = [connectors objectAtIndex: index];

	      if ([con isKindOfClass: [NSNibControlConnector class]] == YES)
		{
		  NSString	*action = [con label];

		  if ([action isEqual: title] == YES)
		    {
		      ASSIGN(currentConnector, con);
		      found = YES;
		      break;
		    }
		}
	    }
	  if (found == NO)
	    {
	      RELEASE(currentConnector);
	      currentConnector = [[NSNibControlConnector alloc] init];
	      [currentConnector setSource: object];
	      [currentConnector setDestination: [NSApp connectDestination]];
	      [currentConnector setLabel: title];
	      [oldBrowser loadColumnZero];
	    }
	  [oldBrowser selectRow: index inColumn: 0];
	}
    }
  else
    {
      for (index = 0; index < numConnectors; index++)
	{
	  id		con = [connectors objectAtIndex: index];
	  NSString	*label = [con label];

	  if ([title hasPrefix: label] == YES)
	    {
	      NSString	*name;
	      id	dest = [NSApp connectDestination];

	      dest = [con destination];
	      name = [[(id<IB>)NSApp activeDocument] nameForObject: dest];
	      name = [label stringByAppendingFormat: @" (%@)", name];
	      if ([title isEqual: name] == YES)
		{
		  NSString	*path = label;

		  ASSIGN(currentConnector, con);
		  /*
		   * Update the main browser to reflect selected connection
		   */
		  path = [@"/" stringByAppendingString: label];
		  if ([con isKindOfClass: [NSNibControlConnector class]] == YES)
		    {
		      path = [@"/target" stringByAppendingString: path];
		    }
		  [newBrowser setPath: path];
		  [NSApp displayConnectionBetween: object
					      and: [con destination]];
		  break;
		}
	    }
	}
    }

  // if it's a control connection select target, if not, don't
  // if([currentConnector isKindOfClass: [NSNib

  [self updateButtons];
}

- (BOOL) browser: (NSBrowser*)sender
selectCellWithString: (NSString*)title
	inColumn: (NSInteger)col
{
  NSMatrix	*matrix = [sender matrixInColumn: col];
  NSInteger		rows = [matrix numberOfRows];
  NSInteger		i;

  for (i = 0; i < rows; i++)
    {
      NSBrowserCell	*cell = [matrix cellAtRow: i column: 0];

      if ([[cell stringValue] isEqual: title] == YES)
        {
	  [matrix selectCellAtRow: i column: 0];
	  return YES;
	}
    }
  return NO;
}

- (void) browser: (NSBrowser*)sender
 willDisplayCell: (id)aCell
	   atRow: (NSInteger)row
	  column: (NSInteger)col
{
  if (sender == newBrowser)
    {
      NSString	*name;

      if (col == 0)
	{
	  if (row >= 0 && row < [outlets count])
	    {
	      name = [outlets objectAtIndex: row];
	      [aCell setStringValue: name];
	      if ([name isEqual: @"target"])
		{
		  [aCell setLeaf: NO];
		}
	      else
		{
		  [aCell setLeaf: YES];
		}
	      [aCell setEnabled: YES];
	    }
	  else
	    {
	      [aCell setStringValue: @""];
	      [aCell setLeaf: YES];
	      [aCell setEnabled: NO];
	    }
	}
      else
	{
	  name = [[sender selectedCellInColumn: 0] stringValue];
	  if ([name isEqual: @"target"] == NO)
	    {
	      NSDebugLog(@"cell selected in actions column without target");
	    }
	  if (row >= 0 && row < [actions count])
	    {
	      [aCell setStringValue: [actions objectAtIndex: row]];
	      [aCell setEnabled: YES];
	    }
	  else
	    {
	      [aCell setStringValue: @""];
	      [aCell setEnabled: NO];
	    }
	  [aCell setLeaf: YES];
	}
    }
  else
    {
      if (row >= 0 && row < [connectors count])
	{
	  NSString	*label;
	  NSString	*name;
	  id		dest = [NSApp connectDestination];

	  label = [[connectors objectAtIndex: row] label];
	  dest = [[connectors objectAtIndex: row] destination];
	  name = [[(id<IB>)NSApp activeDocument] nameForObject: dest];
	  name = [label stringByAppendingFormat: @" (%@)", name];

	  [aCell setStringValue: name];
	  [aCell setEnabled: YES];
	}
      else
	{
	  [aCell setStringValue: @""];
	  [aCell setEnabled: NO];
	}
      [aCell setLeaf: YES];
    }
}

- (void) dealloc
{
  RELEASE(currentConnector);
  RELEASE(connectors);
  RELEASE(actions);
  RELEASE(outlets);
  RELEASE(okButton);
  RELEASE(revertButton);
  [super dealloc];
}

- (void) handleNotification: (NSNotification *)notification
{
  // got the notification...  since we only subscribe to one, just do what
  // needs to be done.
  [self setObject: object]; // resets the browser...
}

- (void) ok: (id)sender
{
  if([currentConnector destination] == nil ||
     [currentConnector source] == nil)
    {
      NSRunAlertPanel(_(@"Problem making connection"),
		      _(@"Please select a valid destination."), 
		      _(@"OK"), nil, nil, nil);
    }
  else if ([connectors containsObject: currentConnector] == YES)
    {
      id con = currentConnector;

      [[(id<IB>)NSApp activeDocument] removeConnector: con];
      [connectors removeObject: con];
      [oldBrowser loadColumnZero];
    }
  else
    {
      NSString	*path;
      id	dest;

      /*
       * Establishing a target/action type connection will automatically
       * remove any previous target/action connection.
       */
      if ([currentConnector isKindOfClass: [NSNibControlConnector class]])
	{
	  NSEnumerator	*enumerator = [connectors objectEnumerator];
	  id		con;

	  while ((con = [enumerator nextObject]) != nil)
	    {
	      if ([con isKindOfClass: [NSNibControlConnector class]])
		{
		  [[(id<IB>)NSApp activeDocument] removeConnector: con];
		  [connectors removeObjectIdenticalTo: con];
		  break;
		}
	    }

	  // select the new action from the list...
	  [self _selectAction: [currentConnector label]];
	}
      [connectors addObject: currentConnector];
      [[(id<IB>)NSApp activeDocument] addConnector: currentConnector];
      
      /*
       * When we establish a connection, we want to highlight it in
       * the browser so the user can see it has been done.
       */
      dest = [currentConnector destination];
      path = [[(id<IB>)NSApp activeDocument] nameForObject: dest];
      path = [[currentConnector label] stringByAppendingFormat: @" (%@)", path];
      path = [@"/" stringByAppendingString: path];
      [oldBrowser loadColumnZero];
      [oldBrowser setPath: path];
    }

  // mark as edited.   
  [super ok: sender];
  [self updateButtons];
}

- (void) setObject: (id)anObject
{
  if (anObject != nil) 
    {
      NSArray		*array;

      [super setObject: anObject];
      RELEASE(connectors);

      /*
       * Create list of existing connections for selected object.
       */
      connectors = [[NSMutableArray alloc] init];
      array = [[(id<IB>)NSApp activeDocument] connectorsForSource: object
	ofClass: [NSNibControlConnector class]];
      [connectors addObjectsFromArray: array];
      array = [[(id<IB>)NSApp activeDocument] connectorsForSource: object
	ofClass: [NSNibOutletConnector class]];
      [connectors addObjectsFromArray: array];

      RELEASE(outlets);
      outlets = RETAIN([[(id<Gorm>)NSApp classManager] allOutletsForObject: object]); 
      DESTROY(actions);

      [oldBrowser loadColumnZero];

      /*
       * See if we can do initial selection based on pre-existing connections.
       */
      if ([NSApp isConnecting] == YES)
	{
	  id dest = [currentConnector destination];
	  unsigned row;

	  for (row = 0; row < [connectors count]; row++)
	    {
	      id<IBConnectors>	con = [connectors objectAtIndex: row];

	      if ([con destination] == dest)
		{
		  ASSIGN(currentConnector, con);
		  [oldBrowser selectRow: row inColumn: 0];
		  break;
		}
	    }
	}

      [newBrowser loadColumnZero];
      if (currentConnector == nil)
	{
	  if ([connectors count] > 0)
	    {
	      currentConnector = RETAIN([connectors objectAtIndex: 0]);
	    }
	  else if ([outlets count] == 1)
	    {
	      [newBrowser selectRow: 0 inColumn: 0];
	      [newBrowser sendAction];
	    }
	}


      if ([currentConnector isKindOfClass: [NSNibControlConnector class]] == YES && 
	  [NSApp isConnecting] == NO)
	{
	  [newBrowser setPath: @"/target"];
	  [newBrowser sendAction];
	}

      [self updateButtons];
    }
}

- (void) updateButtons
{
  if (currentConnector == nil)
    {
      [okButton setEnabled: NO];
    }
  else
    {
      GormDocument *active = (GormDocument *)[(id<IB>)NSApp activeDocument];
      id src = [currentConnector source];
      id dest = [currentConnector destination];

      // highlight or unhiglight the connection depending on
      // the object being connected to.
      if((src == nil || src == [active firstResponder]) ||
	 ((dest == nil || dest == [active firstResponder]) &&
	  [currentConnector isKindOfClass: [NSNibOutletConnector class]] == YES))
	
	{
	  [okButton setEnabled: NO];
	}
      else
	{
	  [okButton setEnabled: YES];
	  if ([connectors containsObject: currentConnector] == YES)
	    {
	      [okButton setTitle: _(@"Disconnect")];
	    }
	  else
	    {
	      [okButton setTitle: _(@"Connect")];
	    }
	}
    }
}

- (BOOL) wantsButtons
{
  return YES;
}
@end
