# Tasklist

## Export
### Dialog
- [x] Base folder picker
- [x] New album option
- [x] Album picker
- [x] Status updates/disablement etc
- [x] Support deep nested albums

### Export process
- [x] Actual export mechanics
- [x] Create album on demand in correct folder
- [x] Reuse existing album
- [x] Edge case - album moved

## Publish 
### Dialog
- [x] Base folder selection
- [x] Status updates/disablement etc

## Publish Process
- [x] Import new images
- [x] Delete removed images
- [x] Update modified image data (delete and reimport)
- [x] Update modified image metadata (delete and reimport)
- [x] Create new albums


## Maintenance/Adhoc Updates
- [x] Create collection set
- [x] Rename collection set
- [x] Delete collection set
- [x] Rename album
- [x] Delete empty album
- [x] Delete album + images
- [x] Album reparent
- [x] Folder reparent
- [x] Collection set / folder creation needs to be inside publish root

## Edge cases
- [x] Ensure new albums & folders are in base folder
- [x] Album manually moved outside of base folder
- [ ] Manual rename (maybe check on publish and update name?)
- [ ] Image manually deleted (recreate on next publish)
- [ ] Folder/album manually deleted (recreate?)
- [x] Recursively delete images in collection set tree
- [ ] Delete images from album which has been moved out of publish root should fail
- [x] Delete album which has been moved out of publish root should fail
- [x] Delete folder which has been moved out of publish root should fail
- [ ] Album reparent is relative to root not publish root (???)
- [ ] Need to confirm it's impossible to setup plugin without setting publish root to something
- [x] Edit publish settings - folder name popup doesn't select previously configured value (because it's trying to match string to tuple)

## Other
- [ ] Performance - optimize out multiple calls
- [ ] Performance - findFolder could start at publish root vs full search and post-filter, when in a publish context
- [ ] Performance - put some timing on stuff, some things seem very slow
- [ ] Should everything be swift?
- [ ] Borrow some utils/setup stuff from piwigo
- [ ] Is it possible to implement "go to" in the photos UI?
- [ ] Review error handling, logging, etc
- [ ] Idea - put a standard check in both applescript and swift libs to check mutations are within publishroot
