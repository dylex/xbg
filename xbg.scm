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
		      (m (map car l))
		      (m (map cdr l))))
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

(define (srt s r t p)
 (let ((x (* (car p) (if (pair? s) (car s) s)))
       (y (* (cdr p) (if (pair? s) (cdr s) s))))
  (cons 
   (+ (car t) (- (* x (cos r)) (* y (sin r))))
   (+ (cdr t) (+ (* x (sin r)) (* y (cos r)))))))

(define (dot p1 p2)
 (+ (* (car p1) (car p2)) (* (cdr p1) (cdr p2))))

(define (for-seq n f)
 (letrec ((loop (lambda (i)
		 (if (< i n) (begin
			      (f i)
			      (loop (succ i)))))))
  (loop 0)))

(define (point-array-set! a i p)
 (vector-set! a (* 2 i) (car p))
 (vector-set! a (succ (* 2 i)) (cdr p)))

(define (make-point-array l)
 (if (pair? l)
  (let* ((n (length l))
	 (a (make-point-array n)))
   (letrec ((fill (lambda (i l)
		   (if (not (null? l)) 
		    (begin
		     (point-array-set! a i (car l))
		     (fill (succ i) (cdr l)))))))
    (fill 0 l))
   a)
  (make-vector (* 2 l) 0.0)))

(define (maparray f a)
 (for-seq (length a) 
  (lambda (i) (vector-set! a i (f (vector-ref a i)))))
 a)

(define (frand a b)
 (+ a (* (rand) (/ (- b a) 2147483647.0))))

(define (drawable-size d)
 (if d
  (cons
   (car (gimp-drawable-width d))
   (car (gimp-drawable-height d)))
 '(0 . 0)))

(define (get-image-layer img l)
 (let* ((layers (gimp-image-get-layers img))
        (n (if (>= l 0) l (+ (car layers) l))))
  (vector-ref (cadr layers) n)))

(define (notempty? x) (and x (not (equal? "" x))))

(define (%d x) (number->string x 10))

(define (draw-tree img draw x0 y0 w0 l0)
 (gimp-image-undo-group-start img)
 (let* ((boxa (make-point-array 4)))
  (gimp-context-set-foreground '(199 126 52))
  (gimp-context-set-gradient "Wood 1")
  (letrec 
   ((draw-branch 
     (lambda (p w a)
      (let* ((l (* l0 (+ 0.5 (/ w w0)) (frand 0.75 1.25)))
	     (w1 (* w (frand 0.85 0.9)))
	     (p1 (srt l a p '(0 . -1)))
	     (p0l (srt w a p '(-1 . 0)))
	     (p0r (srt w a p '(1 . 0)))
	     (p1l (srt w1 a p1 '(-1 . -0.5)))
	     (p1r (srt w1 a p1 '(1 . -0.5)))
	     (prd (mapall - p1r p0r))
	     (dpr (/ (dot (mapall - p0l p0r) prd) (dot prd prd)))
	     (pro (srt dpr 0 p0r prd))
	    )
       (if (> w1 (frand 0.5 2.0))
	(if (or (= w w0) (zero? (rand 5)))
	 (draw-branch p1 w1 (+ (* 0.8 a) (frand -0.2 0.2)))
	 (let ((f (* 0.6 (sin (frand -2 2)))))
	  (draw-branch p1 (* w1 (min 1 (+ 1 f))) (+ (* 0.9 a) f (frand -0.9 -0.3)))
	  (draw-branch p1 (* w1 (min 1 (- 1 f))) (+ (* 0.9 a) f (frand 0.3 0.9))))))
       (point-array-set! boxa 0 p0l)
       (point-array-set! boxa 1 p0r)
       (point-array-set! boxa 2 p1r)
       (point-array-set! boxa 3 p1l)
       (gimp-free-select img 8 boxa CHANNEL-OP-REPLACE TRUE FALSE 0)
       (if (zero? (car (gimp-selection-is-empty img)))
       	(gimp-edit-blend draw CUSTOM-MODE NORMAL-MODE GRADIENT-LINEAR 100 0 REPEAT-NONE FALSE FALSE 1 0 FALSE 
	 (car p0l) (cdr p0l)
	 (car pro) (cdr pro))
	;(gimp-edit-fill draw FOREGROUND-FILL)
       )
    ))))
   (draw-branch (cons x0 y0) w0 0)))
 (gimp-selection-none img)
 (gimp-image-undo-group-end img))

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

	(sunalt (list-ref sunpos 0))
	(sunasc (list-ref sunpos 2))
	(am (> sunasc 0))
	(sunloc (ascpos sunasc))
       )
  (srand (realtime))
	
  (let* ((bg (car (gimp-layer-new img w h RGB-IMAGE "bg" 100 0)))
	 (grad (car (gimp-gradient-new "xbg")))
	 (gstart sunloc)
	 (gend (mapall - '(1 . 1) gstart))
	 (gcs (pwi sunalt `(
			   (-90 . (( 20  20  80) ( 15  15  60) ( 15 15 60)))
			   (-32 . (( 40  40 100) ( 15  15  80) ( 15 15 60)))
			   (-10 . ,(if am
				      '(( 40  40 140) ( 40  40 120) ( 40 40  80))
				      '((140 100 180) ( 70  60 120) ( 40 50 100))))
			   (-5 . ,(if am
				      '((200 200 170) (100 100 140) ( 40  40 100))
				      '((230 150 240) (100 100 200) ( 80 120 180))))
			   (0 . ,(if am
				      '((240 240  80) (140 150 170) ( 80 100 160))
				      '((250 200 190) ( 80 160 240) ( 70 140 210))))
			   (8 . ,(if am
				      '((240 250 170) (170 200 210) (100 130 200))
				      '((185 190 235) ( 70 170 250) ( 55 180 250))))
			   (16 . ,(if am
				      '((230 230 235) (170 220 250) (100 150 220))
				      '((170 180 220) ( 62 191 250) ( 70 200 255))))
			   (32 . (( 60 190 240) (100 200 255) (100 170 250)))
			   (90 . ((120 200 255) (140 200 250) (150 220 250)))))))
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
  
  (let* ((pom (list-ref sunpos 4))
	 (pomn 24)
	 (pomi (modulo (inexact->exact (round (* pomn (succ (/ pom 360))))) pomn))
	 (moon (add-img (string-append "moon-" (%d pomi))))
	 (moonasc (degnorm (+ sunasc pom)))
	 (moonpos (mapall + (mapall * (ascpos moonasc) (mapall - '(1 . 1) (mapall + (pix (drawable-size moon)) (mapall * '(2 . 2) border)))) border))
	 (moonopa (pwi sunalt '((-32 . 100) (16 . 25)))))
   (gimp-image-add-layer img moon -1)
   (gimp-layer-set-offsets moon (posx moonpos) (posy moonpos))
   (gimp-layer-set-mode moon LIGHTEN-ONLY)
   (gimp-layer-set-opacity moon moonopa)
  )

  (if (= (length weather) 6)
   (let* ((wcondicon (list-ref weather 0))
   	  (exttemp (list-ref weather 1))
   	  (curtemp (list-ref weather 2))
	  (cloudp (list-ref weather 3))
	  (rainp (list-ref weather 4))
	  (wind (list-ref weather 5))
	 )
    (if (> (car cloudp) 0)
     (let* ((cp (car cloudp))
	    (bg (get-image-layer img -1))
	    (bghist (gimp-histogram bg HISTOGRAM-VALUE 0 255))
	    (cloud (car (gimp-layer-new img w h RGBA-IMAGE "cloud" 100 NORMAL-MODE))))
      (gimp-image-add-layer img cloud -1)
      (plug-in-solid-noise RUN-NONINTERACTIVE img cloud 0 0 (rand) 15 (/ w 500) (/ h 300))
      (plug-in-normalize RUN-NONINTERACTIVE img cloud)
      ;(plug-in-solid-noise RUN-NONINTERACTIVE img cloud 0 0 (rand) 0 (/ w 120) (/ h 120))
      (plug-in-colortoalpha RUN-NONINTERACTIVE img cloud '(0 0 0))
      (gimp-levels cloud HISTOGRAM-VALUE 0 255 1 0 (car bghist))
      (gimp-levels cloud HISTOGRAM-ALPHA 
       (- 128 (* (/ 256 *pi*) (asin (- (/ cp 50) 1)))) 255
       ;(pwi cp '((0 . 255) (5 . 192) (10 . 160) (33 . 128) (66 . 64) (75 . 0))) 255
       (expt 10 (* 0.6 (expt (/ cp 100) 2)))
       ;(expt 10 (pwi cp '((75 . 0) (100 . 0.6))))
       0 255)
      (plug-in-mblur RUN-NONINTERACTIVE img cloud 0 (* 1 (car wind)) (+ 90 (cadr wind)) 0 0)
     ))

    (if (> (car rainp) 0)
     (let* ((rp (car rainp))
	    (bowloc (mapall - '(1 . 1) sunloc))
	    (rain (car (gimp-layer-new img w h RGBA-IMAGE "rain" 75 OVERLAY-MODE))))
      (gimp-image-add-layer img rain -1)
      (gimp-drawable-fill rain TRANSPARENT-FILL)
      (plug-in-randomize-hurl RUN-NONINTERACTIVE img rain 2 1 FALSE (rand))
      (gimp-hue-saturation rain ALL-HUES 0 0 -90)
      (plug-in-mblur RUN-NONINTERACTIVE img rain 0 (* 1 (car wind)) (+ 90 (cadr wind)) 0 0)
      (gimp-levels rain HISTOGRAM-ALPHA 0 255 (expt 10 (/ rp 100)) 0 255)
      (gimp-context-set-gradient "prism")
      (if (> sunalt 0) 
       (for-each (lambda (m)
	(gimp-edit-blend rain CUSTOM-MODE m GRADIENT-RADIAL 50 75 REPEAT-NONE FALSE FALSE 0 0 FALSE
	 (posx bowloc) (posy bowloc) (posx bowloc) (+ 400 (posy bowloc))))
	 (list SATURATION-MODE COLOR-MODE)))
     ))

    (let* ((maxt (apply max exttemp))
           (mint (apply min exttemp))
	   (ti (lambda (lo hi) (lambda (t) (imap t mint maxt lo hi))))
	   (ty (ti bord 0))
	   (tc (ti '(0 0 255) '(255 0 0)))
	   (tu (ti 1 0))
	   (xe (- w 2))
	   (drawext (lambda (x l) 
		     (if (null? l) x
		      (let ((t (car l)))
		       (drawext 
			(cons (- (car x) 
			 (/ (car (gimp-drawable-width 
				  (add-text (%d t) (cons (car x) (ty t)) (cons 1 (tu t)) (tc t) (- 20 (length l)))))
			  2) 2) x)
			(cdr l))))))
	   (curt (car curtemp))
	   (xl (drawext (list xe) (append (reverse exttemp) (list curt))))
	   (nl (pred (length xl)))
	   (px (cadr xl))
	   (templine (car (gimp-layer-new img (succ (- w px)) bord RGBA-IMAGE "temp" 75 DIFFERENCE-MODE)))
	   (tempvect (car (gimp-vectors-new img "temp")))
	   (tempdata (make-vector (* 6 (length curtemp))))
	   (maketemp (lambda (i t)
		      (if (not (null? t))
		       (let ((x (imap i 0 (- (vector-length tempdata) 6) (+ px 2) (- w 2)))
			     (y (imap (car t) mint maxt (- bord 2) 2)))
			(vector-set! tempdata (+ i 0) x)
			(vector-set! tempdata (+ i 1) y)
			(vector-set! tempdata (+ i 2) x)
			(vector-set! tempdata (+ i 3) y)
			(vector-set! tempdata (+ i 4) x)
			(vector-set! tempdata (+ i 5) y)
			(maketemp (+ i 6) (cdr t))))))
	   (pop (car rainp))
	   (popside (<= (tu curt) 0.5))
           (wcondi (assoc (car wcondicon)
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
	   )
     (if wcondi
      (let* ((wcond (add-img (cdr wcondi)))
	     (wcsize (drawable-size wcond))
	     (wcsize (if wcond (mapall (lambda (x) (* x (/ bord (cdr wcsize)))) wcsize))))
       (gimp-image-add-layer img wcond nl)
       (gimp-layer-scale wcond (car wcsize) (cdr wcsize) 1)
       (gimp-layer-set-offsets wcond (- (car xl) (/ (car wcsize) 2)) 0)
      ))
     (gimp-image-add-layer img templine nl)
     (gimp-layer-set-offsets templine px 0)
     (gimp-image-add-vectors img tempvect -1)
     (maketemp 0 curtemp)
     (gimp-vectors-stroke-new-from-points tempvect 0 (vector-length tempdata) tempdata FALSE)
     (gimp-context-set-foreground '(255 255 255))
     (gimp-context-set-brush "Circle (01)")
     (gimp-context-set-paint-method "gimp-paintbrush")
     (gimp-edit-stroke-vectors templine tempvect)
     (if (> pop 0)
      (add-text (%d pop) (cons (car xl) (if popside (- bord 2) 2)) (cons 1 (if popside 1 0)) '(0 255 0) 10))
     )
   ))

;  (let* ((tree (car (gimp-layer-new img w h RGBA-IMAGE "tree" 100 0))))
;   (gimp-image-add-layer img tree -1)
;   (gimp-drawable-fill tree TRANSPARENT-FILL))

  (if (notempty? out)
   (let ((draw (car (gimp-image-flatten img)))
   	  (tw w)
   	  (nw (/ w nout)))
    (for-seq nout (lambda (n)
     (if (> n 0) (gimp-image-crop img (- w (* (succ n) nw)) h nw 0))
     (let ((outn (string-append out "." (%d n))))
      (file-xpm-save RUN-NONINTERACTIVE img draw outn outn 0))))))

  (gimp-image-undo-enable img)
  img))
