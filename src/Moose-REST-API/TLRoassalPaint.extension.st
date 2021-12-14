Extension { #name : #TLRoassalPaint }

{ #category : #'*Moose-REST-API' }
TLRoassalPaint >> alpha [
	"Return my alpha value, a number between 0.0 and 1.0 where 0.0 is completely transparent and 1.0 is completely opaque."

	^ color alpha asFloat / 255.0
]

{ #category : #'*Moose-REST-API' }
TLRoassalPaint >> asHexString [
	^ color asHexString
]
