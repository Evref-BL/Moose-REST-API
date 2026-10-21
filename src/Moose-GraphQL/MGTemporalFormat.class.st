"
I convert Pharo temporal values to and from the ISO 8601 / RFC 3339 strings used by the GraphQL scalars of Moose GraphQL (class-side only, never raising: printers and parsers answer nil on unsupported or invalid input).

Scalars and formats:
- Date: YYYY-MM-DD (a Date)
- Time: hh:mm:ss[.fff], 24h (a Time)
- DateTime: YYYY-MM-DDThh:mm:ss[.fff]±hh:mm, keeping the original offset (a DateAndTime)
- Duration: ISO 8601 duration such as PT0S, PT2M5S, P1DT2H3M4.5S or -PT5S, using days, hours, minutes and seconds only (a Duration)

Fractions of seconds are printed with at most 3 digits (milliseconds), truncated, trailing zeros stripped, omitted when zero.
Parsing accepts DateTime offsets Z, z, ±hh:mm and ±hhmm (no offset means UTC), and durations made of optional weeks/days and hours/minutes/(fractional) seconds; years and months are rejected because they have no fixed length.

Examples:
	MGTemporalFormat print: (DateAndTime year: 2017 month: 7 day: 4 hour: 4 minute: 5 second: 6 offset: Duration zero). ""'2017-07-04T04:05:06+00:00'""
	MGTemporalFormat parse: 'PT2M5S' as: 'Duration'. ""0:00:02:05""
"
Class {
	#name : 'MGTemporalFormat',
	#superclass : 'Object',
	#category : 'Moose-GraphQL-Core',
	#package : 'Moose-GraphQL',
	#tag : 'Core'
}

{ #category : 'testing' }
MGTemporalFormat class >> isTemporal: anObject [
	"True when anObject is a Date, a Time, a DateAndTime or a Duration (never raises)"

	^ (self scalarNameOf: anObject) notNil
]

{ #category : 'parsing' }
MGTemporalFormat class >> parse: aString as: aScalarName [
	"Pharo value denoted by aString for the temporal scalar named aScalarName (Date, Time, DateTime or Duration), nil when aString is invalid or aScalarName is not temporal (never raises)"

	aScalarName = 'DateTime' ifTrue: [ ^ self parseDateAndTime: aString ].
	aScalarName = 'Date' ifTrue: [ ^ self parseDate: aString ].
	aScalarName = 'Time' ifTrue: [ ^ self parseTime: aString ].
	aScalarName = 'Duration' ifTrue: [ ^ self parseDuration: aString ].
	^ nil
]

{ #category : 'parsing' }
MGTemporalFormat class >> parseDate: aString [
	"Date denoted by aString in strict YYYY-MM-DD form, nil when malformed or not a real calendar day such as 2021-02-30 (never raises)"

	^ self
		  parseWhole: aString
		  with: [ :stream | self readCalendarDateFrom: stream ]
]

{ #category : 'parsing' }
MGTemporalFormat class >> parseDateAndTime: aString [
	"DateAndTime denoted by aString in YYYY-MM-DD[Tt ]hh:mm[:ss[.f+]][Z|z|±hh:mm|±hhmm] form (no offset means UTC), keeping the given offset; nil when malformed (never raises)"

	^ self
		  parseWhole: aString
		  with: [ :stream | self readDateAndTimeFrom: stream ]
]

{ #category : 'parsing' }
MGTemporalFormat class >> parseDuration: aString [
	"Duration denoted by aString in ISO 8601 [-]P[nW][nD][T[nH][nM][n[.f]S]] form, nil when malformed, empty (P, PT) or using years or months (never raises)"

	^ self
		  parseWhole: aString
		  with: [ :stream | self readDurationFrom: stream ]
]

{ #category : 'parsing' }
MGTemporalFormat class >> parseTime: aString [
	"Time denoted by aString in hh:mm[:ss[.f+]] (24h) form, nil when malformed (never raises)"

	^ self
		  parseWhole: aString
		  with: [ :stream | self readClockTimeFrom: stream ]
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> parseWhole: aString with: aReaderBlock [
	"Value read by aReaderBlock from a stream on aString when it consumes the whole string, nil otherwise (not a String, leading or trailing garbage; never raises)"

	^ MGSafe
		  do: [
				  aString isString ifTrue: [
						  | stream value |
						  stream := aString asString readStream.
						  value := aReaderBlock value: stream.
						  (value notNil and: [ stream atEnd ]) ifTrue: [ value ] ] ]
		  default: nil
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> peekDigitIn: aStream [
	"True when the next character of aStream is an ASCII decimal digit"

	^ aStream atEnd not and: [ aStream peek between: $0 and: $9 ]
]

{ #category : 'printing' }
MGTemporalFormat class >> print: anObject [
	"ISO 8601 / RFC 3339 String of anObject when it is temporal (see #scalarNameOf:), nil otherwise (never raises)"

	| scalarName |
	scalarName := self scalarNameOf: anObject.
	scalarName = 'DateTime' ifTrue: [ ^ self printDateAndTime: anObject ].
	scalarName = 'Date' ifTrue: [ ^ self printDate: anObject ].
	scalarName = 'Time' ifTrue: [ ^ self printTime: anObject ].
	scalarName = 'Duration' ifTrue: [ ^ self printDuration: anObject ].
	^ nil
]

{ #category : 'private - printing' }
MGTemporalFormat class >> printCalendarDateOf: aDateOrDateAndTime on: aStream [
	"Print YYYY-MM-DD on aStream; RFC 3339 only allows 4-digit years"

	| year |
	year := aDateOrDateAndTime year.
	(year between: 0 and: 9999) ifFalse: [
		^ self error: 'Year out of the ISO 8601 4-digit range' ].
	aStream
		nextPutAll: (year printPaddedWith: $0 to: 4);
		nextPut: $-;
		nextPutAll:
			(aDateOrDateAndTime monthIndex printPaddedWith: $0 to: 2);
		nextPut: $-;
		nextPutAll:
			(aDateOrDateAndTime dayOfMonth printPaddedWith: $0 to: 2)
]

{ #category : 'private - printing' }
MGTemporalFormat class >> printClockTimeOf: aTimeOrDateAndTime on: aStream [
	"Print hh:mm:ss[.fff] (24h) on aStream, milliseconds truncated and omitted when zero"

	aStream
		nextPutAll: (aTimeOrDateAndTime hour24 printPaddedWith: $0 to: 2);
		nextPut: $:;
		nextPutAll: (aTimeOrDateAndTime minute printPaddedWith: $0 to: 2);
		nextPut: $:;
		nextPutAll: (aTimeOrDateAndTime second printPaddedWith: $0 to: 2).
	self
		printMilliSecondFraction: aTimeOrDateAndTime nanoSecond // 1000000
		on: aStream
]

{ #category : 'printing' }
MGTemporalFormat class >> printDate: aDate [
	"YYYY-MM-DD, nil when aDate is not a Date or its year is outside 0-9999 (never raises)"

	(self scalarNameOf: aDate) = 'Date' ifFalse: [ ^ nil ].
	^ MGSafe
		  do: [
				  String streamContents: [ :stream |
					  self printCalendarDateOf: aDate on: stream ] ]
		  default: nil
]

{ #category : 'printing' }
MGTemporalFormat class >> printDateAndTime: aDateAndTime [
	"YYYY-MM-DDThh:mm:ss[.fff]±hh:mm keeping the offset of aDateAndTime (zero offset printed +00:00), nil when aDateAndTime is not a DateAndTime or its year is outside 0-9999 (never raises)"

	(self scalarNameOf: aDateAndTime) = 'DateTime' ifFalse: [ ^ nil ].
	^ MGSafe
		  do: [
				  String streamContents: [ :stream |
						  self printCalendarDateOf: aDateAndTime on: stream.
						  stream nextPut: $T.
						  self printClockTimeOf: aDateAndTime on: stream.
						  self printOffset: aDateAndTime offset on: stream ] ]
		  default: nil
]

{ #category : 'printing' }
MGTemporalFormat class >> printDuration: aDuration [
	"ISO 8601 duration using days, hours, minutes and seconds only, zero components omitted (e.g. PT0S, PT2M5S, P1DT2H3M4.5S, -PT5S); milliseconds truncated; nil when aDuration is not a Duration (never raises)"

	(self scalarNameOf: aDuration) = 'Duration' ifFalse: [ ^ nil ].
	^ MGSafe
		  do: [
				  | nanoSeconds |
				  nanoSeconds := aDuration asNanoSeconds.
				  String streamContents: [ :stream |
						  self
							  printMilliSeconds: nanoSeconds abs // 1000000
							  negative: nanoSeconds negative
							  on: stream ] ]
		  default: nil
]

{ #category : 'private - printing' }
MGTemporalFormat class >> printMilliSecondFraction: aMilliSeconds on: aStream [
	"Print .f, .ff or .fff (trailing zeros stripped) on aStream; nothing when aMilliSeconds is zero"

	aMilliSeconds = 0 ifTrue: [ ^ self ].
	aStream
		nextPut: $.;
		nextPutAll:
			((aMilliSeconds printPaddedWith: $0 to: 3) trimRight: [ :each |
					 each = $0 ])
]

{ #category : 'private - printing' }
MGTemporalFormat class >> printMilliSeconds: aMilliSeconds negative: aBoolean on: aStream [
	"Print the ISO 8601 duration of aMilliSeconds (positive) on aStream, with a leading minus when aBoolean and the duration is not zero"

	| days hours minutes milliSeconds |
	aMilliSeconds = 0 ifTrue: [ ^ aStream nextPutAll: 'PT0S' ].
	days := aMilliSeconds // 86400000.
	hours := aMilliSeconds \\ 86400000 // 3600000.
	minutes := aMilliSeconds \\ 3600000 // 60000.
	milliSeconds := aMilliSeconds \\ 60000.
	aBoolean ifTrue: [ aStream nextPut: $- ].
	aStream nextPut: $P.
	days > 0 ifTrue: [
			aStream
				print: days;
				nextPut: $D ].
	aMilliSeconds \\ 86400000 = 0 ifTrue: [ ^ self ].
	aStream nextPut: $T.
	hours > 0 ifTrue: [
			aStream
				print: hours;
				nextPut: $H ].
	minutes > 0 ifTrue: [
			aStream
				print: minutes;
				nextPut: $M ].
	milliSeconds > 0 ifTrue: [
			aStream print: milliSeconds // 1000.
			self printMilliSecondFraction: milliSeconds \\ 1000 on: aStream.
			aStream nextPut: $S ]
]

{ #category : 'private - printing' }
MGTemporalFormat class >> printOffset: aDuration on: aStream [
	"Print the UTC offset aDuration as ±hh:mm on aStream (zero offset printed +00:00)"

	| seconds |
	seconds := aDuration asSeconds.
	aStream
		nextPut: (seconds negative
				 ifTrue: [ $- ]
				 ifFalse: [ $+ ]);
		nextPutAll: (seconds abs // 3600 printPaddedWith: $0 to: 2);
		nextPut: $:;
		nextPutAll: (seconds abs \\ 3600 // 60 printPaddedWith: $0 to: 2)
]

{ #category : 'printing' }
MGTemporalFormat class >> printTime: aTime [
	"hh:mm:ss[.fff] (24h, milliseconds truncated, omitted when zero), nil when aTime is not a Time (never raises)"

	(self scalarNameOf: aTime) = 'Time' ifFalse: [ ^ nil ].
	^ MGSafe
		  do: [
				  String streamContents: [ :stream |
					  self printClockTimeOf: aTime on: stream ] ]
		  default: nil
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> readCalendarDateFrom: aStream [
	"Date read from YYYY-MM-DD on aStream, nil when malformed or not a real calendar day (e.g. 2021-02-30)"

	| year month day date |
	year := (self readDigits: 4 from: aStream) ifNil: [ ^ nil ].
	(aStream peekFor: $-) ifFalse: [ ^ nil ].
	month := (self readDigits: 2 from: aStream) ifNil: [ ^ nil ].
	(aStream peekFor: $-) ifFalse: [ ^ nil ].
	day := (self readDigits: 2 from: aStream) ifNil: [ ^ nil ].
	((month between: 1 and: 12) and: [ day between: 1 and: 31 ])
		ifFalse: [ ^ nil ].
	date := Date year: year month: month day: day.
	^ (date year = year and: [
		   date monthIndex = month and: [ date dayOfMonth = day ] ])
		  ifTrue: [ date ]
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> readClockTimeFrom: aStream [
	"Time read from hh:mm[:ss[.f+]] (24h) on aStream, nil when malformed or out of range"

	| hour minute second nanoSecond |
	hour := (self readDigits: 2 from: aStream) ifNil: [ ^ nil ].
	(aStream peekFor: $:) ifFalse: [ ^ nil ].
	minute := (self readDigits: 2 from: aStream) ifNil: [ ^ nil ].
	second := 0.
	nanoSecond := 0.
	(aStream peekFor: $:) ifTrue: [
			second := (self readDigits: 2 from: aStream) ifNil: [ ^ nil ].
			nanoSecond := (self readNanoSecondFractionFrom: aStream) ifNil: [
				              ^ nil ] ].
	((hour between: 0 and: 23) and: [
		 (minute between: 0 and: 59) and: [ second between: 0 and: 59 ] ])
		ifFalse: [ ^ nil ].
	^ Time
		  hour: hour
		  minute: minute
		  second: second
		  nanoSecond: nanoSecond
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> readDateAndTimeFrom: aStream [
	"DateAndTime read from date[Tt ]time[offset] on aStream (see #readCalendarDateFrom:, #readClockTimeFrom: and #readOffsetFrom:), nil when malformed"

	| date time offset |
	date := (self readCalendarDateFrom: aStream) ifNil: [ ^ nil ].
	((aStream peekFor: $T) or: [
		 (aStream peekFor: $t) or: [ aStream peekFor: Character space ] ])
		ifFalse: [ ^ nil ].
	time := (self readClockTimeFrom: aStream) ifNil: [ ^ nil ].
	offset := (self readOffsetFrom: aStream) ifNil: [ ^ nil ].
	^ DateAndTime
		  year: date year
		  month: date monthIndex
		  day: date dayOfMonth
		  hour: time hour24
		  minute: time minute
		  second: time second
		  nanoSecond: time nanoSecond
		  offset: offset
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> readDigits: aCount from: aStream [
	"Integer made of exactly aCount ASCII decimal digits read from aStream, nil when they are not all present"

	| value |
	value := 0.
	aCount timesRepeat: [
			(self peekDigitIn: aStream) ifFalse: [ ^ nil ].
			value := value * 10 + aStream next digitValue ].
	^ value
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> readDurationComponentsFrom: aStream units: someUnits [
	"Total nanoseconds of the <number><designator> components read from aStream.
	someUnits associates each allowed designator with its length in seconds; designators must follow the order of someUnits, each at most once, and only the S (seconds) component may have a fraction.
	Answer nil when malformed or when there is no component."

	| total lastIndex |
	total := 0.
	lastIndex := 0.
	[ self peekDigitIn: aStream ] whileTrue: [
			| value isFractional fraction designator unitIndex |
			value := self readIntegerFrom: aStream.
			isFractional := aStream peek = $..
			fraction := (self readNanoSecondFractionFrom: aStream) ifNil: [
				            ^ nil ].
			aStream atEnd ifTrue: [ ^ nil ].
			designator := aStream next.
			unitIndex := (lastIndex + 1 to: someUnits size)
				             detect: [ :index |
				             (someUnits at: index) key = designator ]
				             ifNone: [ ^ nil ].
			(isFractional and: [ designator ~= $S ]) ifTrue: [ ^ nil ].
			total := total
			         + (value * (someUnits at: unitIndex) value * 1000000000)
			         + fraction.
			lastIndex := unitIndex ].
	^ lastIndex > 0 ifTrue: [ total ]
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> readDurationFrom: aStream [
	"Duration read from [-]P[nW][nD][T[nH][nM][n[.f]S]] on aStream, nil when malformed.
	Years and months (no fixed length), an empty P or T part are rejected."

	| negative datePart timePart nanoSeconds |
	negative := aStream peekFor: $-.
	(aStream peekFor: $P) ifFalse: [ ^ nil ].
	(self peekDigitIn: aStream) ifTrue: [
			datePart := (self readDurationComponentsFrom: aStream units: {
					             ($W -> 604800).
					             ($D -> 86400) }) ifNil: [ ^ nil ] ].
	(aStream peekFor: $T) ifTrue: [
			timePart := (self readDurationComponentsFrom: aStream units: {
					             ($H -> 3600).
					             ($M -> 60).
					             ($S -> 1) }) ifNil: [ ^ nil ] ].
	(datePart isNil and: [ timePart isNil ]) ifTrue: [ ^ nil ].
	nanoSeconds := (datePart ifNil: [ 0 ]) + (timePart ifNil: [ 0 ]).
	^ Duration nanoSeconds: (negative
			   ifTrue: [ nanoSeconds negated ]
			   ifFalse: [ nanoSeconds ])
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> readIntegerFrom: aStream [
	"Integer made of one or more ASCII decimal digits read from aStream, nil when there is none"

	| value |
	(self peekDigitIn: aStream) ifFalse: [ ^ nil ].
	value := 0.
	[ self peekDigitIn: aStream ] whileTrue: [
		value := value * 10 + aStream next digitValue ].
	^ value
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> readNanoSecondFractionFrom: aStream [
	"Nanoseconds of an optional .f+ fraction of second read from aStream (digits beyond the 9th truncated): 0 when absent, nil when the dot has no digit"

	| nanoSeconds scale |
	(aStream peekFor: $.) ifFalse: [ ^ 0 ].
	(self peekDigitIn: aStream) ifFalse: [ ^ nil ].
	nanoSeconds := 0.
	scale := 100000000.
	[ self peekDigitIn: aStream ] whileTrue: [
			nanoSeconds := nanoSeconds + (aStream next digitValue * scale).
			scale := scale // 10 ].
	^ nanoSeconds
]

{ #category : 'private - parsing' }
MGTemporalFormat class >> readOffsetFrom: aStream [
	"UTC offset read from the end of aStream: none (UTC), Z, z, ±hh:mm or ±hhmm; nil when malformed"

	| sign hours minutes |
	aStream atEnd ifTrue: [ ^ Duration zero ].
	((aStream peekFor: $Z) or: [ aStream peekFor: $z ]) ifTrue: [
		^ Duration zero ].
	(aStream peekFor: $+)
		ifTrue: [ sign := 1 ]
		ifFalse: [
				(aStream peekFor: $-) ifFalse: [ ^ nil ].
				sign := -1 ].
	hours := (self readDigits: 2 from: aStream) ifNil: [ ^ nil ].
	aStream peekFor: $:.
	minutes := (self readDigits: 2 from: aStream) ifNil: [ ^ nil ].
	((hours between: 0 and: 23) and: [ minutes between: 0 and: 59 ])
		ifFalse: [ ^ nil ].
	^ Duration minutes: hours * 60 + minutes * sign
]

{ #category : 'testing' }
MGTemporalFormat class >> scalarNameOf: anObject [
	"Name of the GraphQL temporal scalar standing for anObject: DateTime, Date (a Date, not a Month, Week or Year), Time or Duration; nil for any other object (never raises).
	DateAndTime is checked first."

	^ MGSafe
		  do: [
				  (anObject isKindOf: DateAndTime)
					  ifTrue: [ 'DateTime' ]
					  ifFalse: [
							  (anObject isKindOf: Date)
								  ifTrue: [ 'Date' ]
								  ifFalse: [
										  (anObject isKindOf: Time)
											  ifTrue: [ 'Time' ]
											  ifFalse: [
											  (anObject isKindOf: Duration) ifTrue: [ 'Duration' ] ] ] ] ]
		  default: nil
]

{ #category : 'accessing' }
MGTemporalFormat class >> temporalScalarNames [
	"Names of the GraphQL temporal scalars"

	^ #( 'Date' 'Time' 'DateTime' 'Duration' )
]
