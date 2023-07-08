(require 'woman)
(customize-save-variable 'woman-manpath (add-to-list 'woman-manpath (expand-file-name "~/host-man-files")))
(kill-emacs 0)