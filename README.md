# Fix Steps
Just cd into the android root directory and execute the following commands as followed:

0. Clone it
```bash
git clone https://github.com/Rares6567/new_rbe_fix tutorial
```

1. Remove any shell-level `RBE_DIR` override so the tree can choose its own
   client:

```bash
unset RBE_DIR
```

2. Build a patched reclient bundle for the tree:

```bash
bash tutorial/scripts/build_patched_reclient.sh .
```

3. Point the tree defaults at the patched bundle:

```bash
patch -p1 < tutorial/patches/android-rbe-buildbuddyfix-defaults.patch
```

4. Start your build :D
