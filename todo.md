# Tasklist

## Export
### Dialog
- [x] Base folder picker
- [x] New album option
- [x] Album picker
- [x] Status updates/disablement etc
- [x] Support deep nested albums
- [ ] Rescan button

### Export process
- [x] Actual export mechanics
- [x] Create album on demand in correct folder
- [x] Reuse existing album
- [ ] Edge case - album moved during export process

## Publish 
### Dialog
- [x] Base folder selection
- [x] Status updates/disablement etc
- [ ] Rescan button

## Publish Process
- [x] Import new images
- [x] Delete removed images
- [ ] Update modified images
    - [x] Implement replace in swift code
    - [ ] Can't update metadata, so maybe should be delete & reimport? Need to decide
- [x] Create new albums

## Maintenance/Adhoc Updates
- [x] Create collection set
- [x] Rename collection set
- [x] Delete collection set
- [x] Rename album
- [ ] Delete album
- [ ] Album reparent
- [ ] Folder reparent

## Edge cases
- [ ] Ensure new albums & folders are in base folder
- [ ] Album manually moved outside of base folder
- [ ] Manual rename (maybe check on publish and update name?)
- [ ] Image manually deleted (recreate on next publish)
- [ ] Folder/album manually deleted (recreate?)
- [ ] Recursively delete images in collection set tree

## Other
- [ ] Performance - optimize out multiple calls
- [ ] Should everything be swift?

## Notes
 - Current version of photos proxy needs explict access to directory where replacement files are located due to sandboxing. This is currently downloads for testing, need to see what happens when it's the LR output tmp folder. 