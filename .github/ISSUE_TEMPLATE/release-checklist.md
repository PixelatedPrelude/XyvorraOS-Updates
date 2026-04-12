## Release checklist — vX.X.X

- [ ] All changes tested in VM
- [ ] `release.json` filled out correctly
- [ ] File paths in `release.json` match actual repo paths
- [ ] `pre.sh` and `post.sh` hooks tested
- [ ] `manifest.json` updated with new release entry
- [ ] `VERSION` file updated
- [ ] Merged `dev` → `main`
- [ ] Git tag pushed: `git tag v1.x.x && git push origin v1.x.x`
- [ ] GitHub Release created with changelog notes
