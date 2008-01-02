(define (succ x) (+ x 1))
(define (pred x) (- x 1))
(define (recip x) (/ 1 x))

(define (comp f g) (lambda (x) (f (g x))))

(define mapall (lambda a
 (let ((f (car a))
       (l (cdr a)))
  (letrec 
   ((m (lambda (l)
	(let ((x (car l)))
	 (cond
	  ((null? x) ())
	  ((pair? x) (cons
		      (m (mapcar car l))
		      (m (mapcar cdr l))))
	  (#t (apply f l)))))))
   (m l)))))

(define (interp t a b x y)
 (if (= a b) 0 (+ x (* (- t a) (/ (- y x) (- b a))))))
(define (imap t a b x y)
 (mapall (lambda (x y) (interp t a b x y)) x y))

(define (pwi t l)
 (let ((ax (car l))
       (r (cdr l)))
  (if (or (< t (car ax)) (null? r)) (cdr ax)
  (let ((by (car r)))
   (if (<= t (car by))
    (imap t (car ax) (car by) (cdr ax) (cdr by))
    (pwi t r))))))

(define (degnorm x)
 (cond 
  ((> x 180) (degnorm (- x 360)))
  ((< x -180) (degnorm (+ x 360)))
  (#t x)))

(define (drawable-size d)
 (if d
  (cons
   (car (gimp-drawable-width d))
   (car (gimp-drawable-height d)))
 '(0 . 0)))

(define (get-image-layer img l)
 (let* ((layers (gimp-image-get-layers img))
        (n (if (>= l 0) l (+ (car layers) l))))
  (aref (cadr layers) n)))

(define (notempty? x) (and x (not (equal? "" x))))

(define (%d x) (number->string x 10))

(define (xbg out nout dim sunpos weather)
 (let* ((w (car dim))
	(h (cdr dim))
	(dim1 (mapall pred dim))
	(pix (lambda (xy) (mapall / xy dim1)))
	(pos (lambda (xy) (mapall * dim1 xy)))
	(posx (comp car pos))
	(posy (comp cdr pos))

	(img (car (gimp-image-new w h RGB)))
	(_ (gimp-image-undo-disable img))

	(bord 50)
	(border (pix (cons bord bord)))
	(add-img (lambda (file)
		  (if (notempty? file)
		   (let* ((path (string-append xbg-dir "images/" file ".png"))
			  (fimg (car (gimp-file-load RUN-NONINTERACTIVE path file)))
			  (fl (car (gimp-image-get-active-layer fimg)))
			  (l (car (gimp-layer-new-from-drawable fl img))))
		    (gimp-image-delete fimg)
		    (gimp-drawable-set-name l file)
		    l))))
	(add-text (lambda (text pos align color size)
		   (let* ((font "Sans")
			  (ext (gimp-text-get-extents-fontname text size PIXELS font))
			  (pos (mapall - pos (mapall * align (cons (car ext) (cadr ext))))))
		    (gimp-context-set-foreground color)
		    (car (gimp-text-fontname img -1 (car pos) (cdr pos) text 0 TRUE size PIXELS font)))))
	(ascpos (lambda (asc) (pwi asc
			       '((-180 0.5 . 1)
			         ( -90 0   . 1)
				 ( -45 0   . 0)
				 (  45 1   . 0)
				 (  90 1   . 1)
				 ( 180 0.5 . 1)))))

	(sunalt (nth 0 sunpos))
	(sunasc (nth 2 sunpos))
	(am (> sunasc 0))
	(sunloc (ascpos sunasc))
       )
  (srand (realtime))
	
  (let* ((bg (car (gimp-layer-new img w h RGB-IMAGE "bg" 100 0)))
	 (grad (car (gimp-gradient-new "xbg")))
	 (gstart sunloc)
	 (gend (mapall - '(1 . 1) gstart))
	 (gcs (pwi sunalt (list
			   (cons -90  '(( 20  20  80) ( 15  15  60) ( 15 15 60)))
			   (cons -32  '(( 40  40 100) ( 15  15  80) ( 15 15 60)))
			   (cons -10 (if am
				      '(( 40  40 140) ( 40  40 120) ( 40 40  80))
				      '((140 100 180) ( 70  60 120) ( 40 50 100))))
			   (cons  -5 (if am
				      '((200 200 170) (100 100 140) ( 40  40 100))
				      '((230 150 240) (100 100 200) ( 80 120 180))))
			   (cons   0 (if am
				      '((240 240  80) (140 150 170) ( 80 100 160))
				      '((250 200 190) ( 80 160 240) ( 70 140 210))))
			   (cons   8 (if am
				      '((240 250 170) (170 200 210) (100 130 200))
				      '((185 190 235) ( 70 170 250) ( 55 180 250))))
			   (cons  16 (if am
				      '((230 230 235) (170 220 250) (100 150 220))
				      '((170 180 220) ( 62 191 250) ( 70 200 255))))
			   (cons  32  '(( 60 190 240) (100 200 255) (100 170 250)))
			   (cons  90  '((120 200 255) (140 200 250) (150 220 250)))))))
   (gimp-image-add-layer img bg 0)
   (gimp-gradient-segment-range-split-uniform grad 0 0 2)
   (gimp-gradient-segment-set-left-color  grad 0 (car   gcs) 100)
   (gimp-gradient-segment-set-right-color grad 0 (cadr  gcs) 100)
   (gimp-gradient-segment-set-left-color  grad 1 (cadr  gcs) 100)
   (gimp-gradient-segment-set-right-color grad 1 (caddr gcs) 100)
   (gimp-context-set-gradient grad)
   (gimp-edit-blend bg CUSTOM-MODE NORMAL-MODE GRADIENT-RADIAL 100 0 REPEAT-NONE FALSE FALSE 0 0 TRUE
    (posx gstart) (posy gstart) (posx gend) (posy gend))
   (gimp-gradient-delete grad)

  )

  (if (> sunalt 0)
   (let* ((bg (get-image-layer img -1))
   	  (ang (* *pi* (/ sunasc 180)))
	  (pos (cons (/ (+ (sin ang) 1) 2) (- 1 (cos ang))))
          ;(sun (gimp-layer-new img w h RGBA-IMAGE "sun" 100 NORMAL-MODE))
	  ;(flare (gimp-layer-new img w h RGBA-IMAGE "flare" 50 SCREEN-MODE))
	 )
    (plug-in-flarefx RUN-NONINTERACTIVE img bg (posx pos) (posy pos))
    ;(gimp-image-add-layer img sun -1)
    ;(gimp-image-add-layer img flare -1)
   )
   (let* ((star (car (gimp-layer-new img w h RGBA-IMAGE "star" 100 NORMAL-MODE))))
    (gimp-image-add-layer img star -1)
    (gimp-drawable-fill star TRANSPARENT-FILL)
    (plug-in-randomize-hurl RUN-NONINTERACTIVE img star 1 1 FALSE (rand))
    (gimp-hue-saturation star ALL-HUES 0 0 -95)
    (plug-in-colortoalpha RUN-NONINTERACTIVE img star '(0 0 0))
    (gimp-levels star HISTOGRAM-ALPHA (interp sunalt -90 0 128 255) 255 1 0 255)
   )
  )
  
  (let* ((pom (/ (nth 4 sunpos) 100))
	 (pomn 24)
	 (pomi (trunc (fmod (+ (* pomn (/ (succ pom) 2)) 0.5) pomn)))
	 (moon (add-img (string-append "moon-" (%d pomi))))
	 (moonasc (degnorm (+ sunasc (* 180 (succ pom)))))
	 (moonpos (mapall + (mapall * (ascpos moonasc) (mapall - '(1 . 1) (mapall + (pix (drawable-size moon)) (mapall * '(2 . 2) border)))) border))
	 (moonopa (pwi sunalt '((-32 . 100) (16 . 25)))))
   (gimp-image-add-layer img moon -1)
   (gimp-layer-set-offsets moon (posx moonpos) (posy moonpos))
   (gimp-layer-set-mode moon LIGHTEN-ONLY)
   (gimp-layer-set-opacity moon moonopa)
  )

  (if (notempty? weather)
   (begin
    (if (> (nth 4 weather) 0)
     (let* ((cp (nth 4 weather))
	    (wspd (nth 6 weather))
	    (wdir (nth 7 weather))
	    (bg (get-image-layer img -1))
	    (bghist (gimp-histogram bg HISTOGRAM-VALUE 0 255))
	    (cloud (car (gimp-layer-new img w h RGBA-IMAGE "cloud" 100 NORMAL-MODE))))
      (gimp-image-add-layer img cloud -1)
      (plug-in-plasma RUN-NONINTERACTIVE img cloud (rand) (/ w 800))
      (gimp-desaturate cloud)
      (plug-in-normalize RUN-NONINTERACTIVE img cloud)
      ;(plug-in-solid-noise RUN-NONINTERACTIVE img cloud 0 0 (rand) 0 (/ w 120) (/ h 120))
      (plug-in-colortoalpha RUN-NONINTERACTIVE img cloud '(0 0 0))
      (gimp-levels cloud HISTOGRAM-VALUE 0 255 1 0 (car bghist))
      (gimp-levels cloud HISTOGRAM-ALPHA 
       (- 128 (* (/ 256 *pi*) (asin (- (/ cp 50) 1)))) 255
       ;(pwi cp '((0 . 255) (5 . 192) (10 . 160) (33 . 128) (66 . 64) (75 . 0))) 255
       (pow 10 (* 0.6 (pow (/ cp 100) 2)))
       ;(pow 10 (pwi cp '((75 . 0) (100 . 0.6))))
       0 255)
      (plug-in-mblur RUN-NONINTERACTIVE img cloud 0 (* 1 wspd) (+ 90 wdir) 0 0)
     ))

    (if (> (nth 5 weather) 0)
     (let* ((rp (nth 5 weather))
	    (wspd (nth 6 weather))
	    (wdir (nth 7 weather))
	    (bowloc (mapall - '(1 . 1) sunloc))
	    (rain (car (gimp-layer-new img w h RGBA-IMAGE "rain" 100 ADDITION-MODE))))
      (gimp-image-add-layer img rain -1)
      (gimp-drawable-fill rain TRANSPARENT-FILL)
      (plug-in-randomize-hurl RUN-NONINTERACTIVE img rain 1 1 FALSE (rand))
      (gimp-hue-saturation rain ALL-HUES 0 0 -90)
      (plug-in-mblur RUN-NONINTERACTIVE img rain 0 (* 1 wspd) (+ 90 wdir) 0 0)
      (gimp-levels rain HISTOGRAM-VALUE 0 255 (pow 10 (- (/ rp 50) 1)) 0 255)
      (gimp-context-set-gradient "prism")
      (if (> sunalt 0)
       (gimp-edit-blend rain CUSTOM-MODE COLOR-MODE GRADIENT-RADIAL 90 75 REPEAT-NONE FALSE FALSE 0 0 FALSE
        (posx bowloc) (posy bowloc) (posx bowloc) (+ 400 (posy bowloc))))
     ))

    (let* ((wcondi (assoc (car weather)
		    '((skc . "sun")		(nskc . "sun")
		      (few . "sun")	  	(nfew . "sun")
		      (sct . "partlysun") 	(nsct . "partlysun")
		      (bkn . "partly")	  	(nbkn . "partly")
		      (ovc . "cloudy") 	  	(novc . "cloudy")
		      (hazy . "hazesun")
		      (fg . "fog") 	  	(nfg . "fog")
		      (ra . "rain") 	  	(nra . "rain")
		      (shra . "rain")
		      (hi_shwrs . "raincloudy")	(hi_nshwrs . "raincloudy")
		      (scttsra . "lightning")   (nscttsra . "lightning")
		      (tsra . "lightning")	(ntsra . "lightning")
		      (rasn . "rainsnow") 	(nrasn . "rainsnow")
		      (raip . "rainhail") 	(nraip . "rainhail")
		      (mix . "rainsnow") 	(mix . "rainsnow")
		      (sn . "snow") 	  	(nsn . "snow")
		      (fzra . "ice") 	  	(nfzra . "ice")
		      (ip . "hail") 	  	(nip . "hail")
		     )))
	   (wcond (if wcondi (add-img (cdr wcondi)) #f))
	   (wcsize (drawable-size wcond))
	   (wcsize (if wcond (mapall (lambda (x) (* x (/ bord (cdr wcsize)))) wcsize))))
     (if wcond
      (begin
       (gimp-image-add-layer img wcond -1)
       (gimp-layer-scale wcond (car wcsize) (cdr wcsize) 1)
       (gimp-layer-set-offsets wcond (- w (+ 25 (car wcsize))) 0)
      )))

    (let* ((hit (nth 2 weather))
	   (lot (nth 1 weather))
	   (curt (nth 3 weather))
	   (pop (nth 5 weather))
	   (ti (lambda (lo hi) (imap curt lot hit lo hi)))
	   (hic '(255 0 0))
	   (loc '(0 0 255))
	   (x (- w 2))
	   (hiy 2)
	   (loy (- bord 2))
	   (hi (add-text (%d hit) (cons x hiy) '(1 . 0) hic 20))
	   (lo (add-text (%d lot) (cons x loy) '(1 . 1) loc 20))
	   (hilow (- x (max (car (gimp-drawable-width lo)) (car (gimp-drawable-width hi)))))
	   (popl (if (> pop 0) (add-text (%d pop) (cons (min (- w 27) (- hilow 3)) loy) '(1 . 1) '(0 255 0) 10)))
	   (cur (add-text (%d curt) (cons (- hilow 4) (/ bord 2)) (cons 1 0.5) (ti loc hic) 20)))
    )
   ))

  (if (notempty? out)
   (let ((draw (car (gimp-image-flatten img)))
   	  (tw w)
   	  (nw (/ w nout)))
    (letrec
     ((save-part
       (lambda (n)
	(let ((outn (string-append out "." (%d n))))
	 (file-xpm-save RUN-NONINTERACTIVE img draw outn outn 0)
	 (if (< (succ n) nout)
	  (begin
	   (gimp-image-crop img (- w (* (succ n) nw)) h nw 0)
	   (save-part (succ n))))))))
     (save-part 0))))

  (gimp-image-undo-enable img)
  img))
