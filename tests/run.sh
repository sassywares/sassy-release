#!/usr/bin/env bash
T=$(mktemp -d); R=$T/work; HERE=$(cd "$(dirname "$0")/.." && pwd); S=$HERE/release.sh
mkdir -p $R; cd $R; trap "rm -rf $T" EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mk() { # name kind
  git init -q --bare -b main $R/$1.git; git init -q -b main $R/$1; cd $R/$1
  git remote add origin $R/$1.git
  if [ "$2" = pkg ]; then printf '{\n  "name": "x",\n  "version": "0.2.0"\n}\n' > package.json; else echo 0.1.0 > VERSION; fi
  echo a > lib.txt; mkdir -p docs; echo d > docs/a.md
  git add -A; git commit -qm init; git push -q origin main; }
run() { bash $S; echo "exit=$?"; }
tags() { echo "local: $(git tag|tr '\n' ' ') remote: $(git ls-remote --tags origin|awk '{print $2}'|tr '\n' ' ')"; }
echo "== a first release"; mk a v; run; tags; cat VERSION
echo "== b consumer change"; echo b >> lib.txt; git commit -qam "feat"; run; tags; cat VERSION; git log --oneline|head -2; git status -sb|head -1
echo "== c ignored only"; echo x >> docs/a.md; git commit -qam docs; run; tags
echo "== d bumped untagged"; echo 0.1.5 > VERSION; git commit -qam "bump"; run; tags; cat VERSION
echo "== e dirty"; echo z >> lib.txt; run; git checkout -q lib.txt; echo new > untracked; run; rm untracked
echo "== f feature branch"; git checkout -qb feat; echo f >> lib.txt; git commit -qam f; run; tags; git ls-remote origin refs/heads/feat|wc -l
echo "== g package.json (npm)"; cd $R; mk g pkg; run; tags; echo c >> lib.txt; git commit -qam c; run; tags; grep version package.json
echo "== g2 package.json (no npm)"; echo c2 >> lib.txt; git commit -qam c2; PATH=/usr/bin:/bin bash $S; echo "exit=$?"; grep version package.json; tags
echo "== h custom ignore"; cd $R; mk h v; mkdir bin; printf '# c\nlib.txt\nnotes/\n*.md\nbin/\n' > bin/release-ignore; git add -A; git commit -qm ign; run; tags
echo y >> lib.txt; mkdir notes; echo n > notes/n; echo r > README.md; git add -A; git commit -qm ignored; run; tags
mkdir src; echo s > src/s.txt; git add -A; git commit -qm src; run; tags; cat VERSION
echo "== i push rejected"; cd $R; mk i v; run >/dev/null; echo i >> lib.txt; git commit -qam i
git clone -q $R/i.git $R/i2; (cd $R/i2; echo o>o; git add o; git commit -qm other; git push -q origin main)
run; tags; cat VERSION
echo "== j tag push fails once"; cd $R; mk j v; run >/dev/null; echo j >> lib.txt; git commit -qam j
cat > $R/j.git/hooks/pre-receive <<'H'
#!/bin/sh
while read o n ref; do case "$ref" in refs/tags/*) [ -f "$GIT_DIR/once" ] || { touch "$GIT_DIR/once"; echo "tag rejected once" >&2; exit 1; } ;; esac; done
H
chmod +x $R/j.git/hooks/pre-receive
run; tags; echo "-- rerun"; run; tags
echo "== k remote has tag, local not fetched"; cd $R; mk k v; run >/dev/null; echo k >> lib.txt; git commit -qam k
git clone -q $R/k.git $R/k2; (cd $R/k2; echo 0.1.1 > VERSION; git commit -qam bump; git push -q origin main; git tag -a v0.1.1 -m v0.1.1; git push -q origin v0.1.1)
git pull -q --no-rebase --no-edit origin main 2>&1|tail -1; git tag -d v0.1.1 >/dev/null 2>&1; run; tags; cat VERSION
echo "== l regressed"; cd $R; mk l v; run >/dev/null; echo 0.0.9 > VERSION; git commit -qam reg; run; tags
echo "== m next exists"; cd $R; mk m v; run >/dev/null; git tag -a v0.1.1 -m x HEAD~0; git push -q origin v0.1.1; git tag -d v0.1.1 >/dev/null; git fetch -q --tags; git tag -d v0.1.1 >/dev/null; git push -q origin :refs/tags/v0.1.1
git tag -a v0.1.1 -m x; git push -q origin v0.1.1; git tag -d v0.1.1 >/dev/null  # remote-only v0.1.1 but highest becomes 0.1.1 after fetch -> expect lower/other die
echo m >> lib.txt; git commit -qam m; run; git log --oneline | head -1
echo "== n rename into ignored"; cd $R; mk n v; run >/dev/null; git mv lib.txt docs/lib.txt; git commit -qm mv; run; tags
echo "== o nested version"; cd $R; mk o pkg; printf '{\n    "config": {"version": "9.9.9"},\n    "name": "x",\n    "version": "0.2.0"\n}\n' > package.json; git commit -qam n; git push -q origin main; run >/dev/null; echo o >> lib.txt; git commit -qam o; run; cat package.json; tags
echo "== p leading zero"; cd $R; mk p v; echo 01.2.3 > VERSION; git commit -qam z; run
echo "== q commit hook fails"; cd $R; mk q v; run >/dev/null; echo q >> lib.txt; git commit -qam q
printf '#!/bin/sh\necho "hook says no" >&2\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
run; git status --porcelain; cat VERSION; tags
echo "== r prerelease"; cd $R; mk r v; echo 1.0.0-beta.1 > VERSION; git commit -qam pre; run; tags; echo r >> lib.txt; git commit -qam r; run; tags
echo "== s bad ignore"; cd $R; mk s v; mkdir bin; echo '**/x' > bin/release-ignore; git add -A; git commit -qm i; run
echo "== t core.sshCommand / GIT_SSH respected"; cd $R; mk t v; run >/dev/null
printf '#!/bin/sh\necho "$@" > %s/sshlog\nexit 255\n' $R > $R/fakessh; chmod +x $R/fakessh
git remote set-url origin ssh://nohost/x; git config core.sshCommand "$R/fakessh -x"; rm -f $R/sshlog
run; echo "log: $(cat $R/sshlog)"
git config --unset core.sshCommand; rm -f $R/sshlog; GIT_SSH=$R/fakessh run; echo "GIT_SSH log (expect no BatchMode): $(cat $R/sshlog)"
echo "== u origin unreachable at v<next> check"; cd $R; mk u v; run >/dev/null; echo u >> lib.txt; git commit -qam u
mkdir -p $R/wrap; REALGIT=$(command -v git)
printf '#!/bin/sh\nif [ "$1" = ls-remote ] && [ "$2" = --tags ] && [ "$3" = origin ] && [ "$4" = refs/tags/v0.1.1 ]; then echo "simulated outage" >&2; exit 128; fi\nexec %s "$@"\n' $REALGIT > $R/wrap/git; chmod +x $R/wrap/git
h=$(git rev-parse HEAD); PATH=$R/wrap:$PATH bash $S; echo "exit=$?"; echo "head unchanged: $([ $h = $(git rev-parse HEAD) ] && echo yes || echo NO) version: $(cat VERSION)"; tags
echo "== v stale local tag deleted on origin"; cd $R; mk v v; run >/dev/null; git tag -a v0.3.0 -m stale; echo v >> lib.txt; git commit -qam v; run; tags
echo "== w nothing changed since tag"; cd $R; mk w v; run >/dev/null; run
echo "== x default ignore: bin/release ignored, other bin/ files count"; cd $R; mk x v; run >/dev/null
mkdir bin; echo r > bin/release; git add -A; git commit -qm vendored; run; tags
echo tool > bin/tool; git add -A; git commit -qm tool; run; tags; cat VERSION
