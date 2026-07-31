LIBDIR := lib
-include $(LIBDIR)/main.mk

$(LIBDIR)/main.mk:
ifneq (,$(shell grep "path *= *$(LIBDIR)" .gitmodules 2>/dev/null))
	git submodule sync
	git submodule update --init
else
ifneq (,$(wildcard $(ID_TEMPLATE_HOME)))
	ln -s "$(ID_TEMPLATE_HOME)" $(LIBDIR)
else
	git clone -q --depth 10 -b main \
	    https://github.com/martinthomson/i-d-template $(LIBDIR)
endif
endif

# Style the editor's copy with i-d-template's stylesheet plus the local
# corrections in style-overrides.css. Concatenated rather than forked because
# lib/ is a clone: edits there are not tracked and vanish on the next update.
#
# These assignments have to come after the include. config.mk sets both with
# `:=`, so an earlier definition would just be overwritten, and XML2RFC_HTML
# has to be restated because it captured the old path when it was expanded.
RFC_CSS := rfc-style.css
XML2RFC_CSS := $(RFC_CSS)
XML2RFC_HTML := --html --css=$(RFC_CSS) --metadata-js-url=/dev/null

$(RFC_CSS): $(LIBDIR)/v3.css style-overrides.css
	cat $^ > $@

# main.mk's pattern rule captured the old stylesheet as a prerequisite when it
# was read, so the dependency has to be restated for the generated one.
$(addsuffix .html,$(drafts)): $(RFC_CSS)

clean::
	-rm -f $(RFC_CSS)
