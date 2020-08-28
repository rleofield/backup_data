

grep -rlZ '# version' . | xargs -0 sed -i 's/version 20.01.1/version 20.08.1/g'


Kontrolle:
grep "# version" *.sh
