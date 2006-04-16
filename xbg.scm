(define (succ x) (+ x 1))
(define (pred x) (- x 1))
(define (recip x) (/ 1 x))

(define (comp f g) (lambda (x) (f (g x))))

(define map (lambda a
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
	  (t (apply f l)))))))
   (m l)))))

(define (interp t a b x y)
 (+ x (* (- t a) (/ (- y x) (- b a)))))
(define (imap t a b x y)
 (map (lambda (x y) (interp t a b x y)) x y))

(define (pwi t l)
 (let ((ax (car l))
       (r (cdr l)))
  (if (or (< t (car ax)) (null? r)) (cdr ax)
  (let ((by (car r)))
   (if (<= t (car by))
    (imap t (car ax) (car by) (cdr ax) (cdr by))
    (pwi t r))))))

(define xbg-img-dir "/home/dylan/media/pix/xbg/")

(define (degnorm x)
 (cond 
  ((> x 180) (degnorm (- x 360)))
  ((< x -180) (degnorm (+ x 360)))
  (t x)))

(define (drawable-size d)
 (cons
  (car (gimp-drawable-width d))
  (car (gimp-drawable-height d))))

(define (xbg out w h alt asc pom)
 (let* ((img (car (gimp-image-new w h RGB)))
	(bg (car (gimp-layer-new img w h RGB-IMAGE "bg" 100 0)))
	(grad (car (gimp-gradient-new "xbg")))
	(dim (cons w h))
	(dim1 (map pred dim))
	(pix (lambda (xy) (map / xy dim1)))
	(pos (lambda (xy) (map * dim1 xy)))
	(posx (comp car pos))
	(posy (comp cdr pos))

	(border (pix '(50 . 50)))
	(ascpos (lambda (asc) (pwi asc '(
				(-180 0.5 . 1)
				( -90 0   . 1)
				( -45 0   . 0)
				(  45 1   . 0)
				(  90 1   . 1)
				( 180 0.5 . 1)))))
	(am (> asc 0))
	(gstart (ascpos asc))
	(gend (map - '(1 . 1) gstart))
	(gcs (pwi alt (list
		       (cons -90  '(( 20  20  80) ( 20  20  80) ( 20 20 80)))
		       (cons -32  '(( 60  60 120) ( 20  20 110) ( 20 20 80)))
		       (cons -10 (if am
				  '(( 40  40 140) ( 40  40 120) ( 40 40  80))
				  '((170 120 210) (100  90 170) ( 60 80 170))))
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
		       (cons  90  '((120 200 255) (140 200 250) (150 220 250))))))

	(pom (/ pom 100))
        (pomn 24)
        (pomi (trunc (fmod (+ (* pomn (/ (succ pom) 2)) 0.5) pomn)))
	(moonfile (string-append xbg-img-dir "moon-" (number->string pomi 10) ".png"))
	(moonimg (car (gimp-file-load RUN-NONINTERACTIVE moonfile moonfile)))
	(moonimgl (car (gimp-image-get-active-layer moonimg)))
	(moon (car (gimp-layer-new-from-drawable moonimgl img)))
	(moonasc (degnorm (+ asc (* 180 (succ pom)))))
	(moonpos (map + (map * (ascpos moonasc) (map - '(1 . 1) (map + (pix (drawable-size moon)) (map * '(2 . 2) border)))) border))
	(moonopa (pwi alt '((-32 . 100) (16 . 25))))
       )
  (gimp-image-undo-disable img)
  (gimp-image-add-layer img bg 0)
  (gimp-gradient-segment-range-split-uniform grad 0 0 2)
  (gimp-gradient-segment-set-left-color  grad 0 (car   gcs) 100)
  (gimp-gradient-segment-set-right-color grad 0 (cadr  gcs) 100)
  (gimp-gradient-segment-set-left-color  grad 1 (cadr  gcs) 100)
  (gimp-gradient-segment-set-right-color grad 1 (caddr gcs) 100)
  (gimp-context-set-gradient grad)
  (gimp-edit-blend bg CUSTOM-MODE 0 GRADIENT-RADIAL 100 0 REPEAT-NONE FALSE FALSE 0 0 TRUE
   (posx gstart) (posy gstart) (posx gend) (posy gend))
  (gimp-gradient-delete grad)

  (gimp-drawable-set-name moon "moon")
  (gimp-image-add-layer img moon -1)
  (gimp-layer-set-offsets moon (posx moonpos) (posy moonpos))
  (gimp-layer-set-mode moon LIGHTEN-ONLY)
  (gimp-layer-set-opacity moon moonopa)

  (if (not (equal? "" out))
   (let ((draw (car (gimp-image-flatten img))))
    (file-ppm-save 1 1 draw out out 1)))
  img))
