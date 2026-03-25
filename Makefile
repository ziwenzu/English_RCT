MAIN_TEX := writing/draft.tex
OVERLEAF_REPO ?= /Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/Censorship

.PHONY: pdf clean sync-overleaf overleaf-status

pdf:
	latexmk -pdf -interaction=nonstopmode -halt-on-error -cd "$(MAIN_TEX)"
	cp writing/draft.pdf writing/.draft.pdf.keep
	latexmk -c -cd "$(MAIN_TEX)"
	rm -f writing/draft.aux writing/draft.bbl writing/draft.bcf writing/draft.blg writing/draft.fdb_latexmk writing/draft.fls writing/draft.log writing/draft.out writing/draft.ptc writing/draft.run.xml writing/draft.bcf-SAVE-ERROR
	mv writing/.draft.pdf.keep writing/draft.pdf

clean:
	latexmk -c -cd "$(MAIN_TEX)"
	rm -f writing/draft.aux writing/draft.bbl writing/draft.bcf writing/draft.blg writing/draft.fdb_latexmk writing/draft.fls writing/draft.log writing/draft.out writing/draft.ptc writing/draft.run.xml writing/draft.bcf-SAVE-ERROR

sync-overleaf:
	test -d "$(OVERLEAF_REPO)/.git"
	mkdir -p "$(OVERLEAF_REPO)/figures" "$(OVERLEAF_REPO)/tables"
	cp writing/draft.tex "$(OVERLEAF_REPO)/draft.tex"
	cp writing/ref.bib "$(OVERLEAF_REPO)/ref.bib"
	rsync -a --delete writing/figures/ "$(OVERLEAF_REPO)/figures/"
	rsync -a --delete writing/tables/ "$(OVERLEAF_REPO)/tables/"

overleaf-status:
	git -C "$(OVERLEAF_REPO)" status --short
