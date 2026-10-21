"
Please comment me using the following template inspired by Class Responsibility Collaborator (CRC) design:

For the Class part:  State a one line summary. For example, ""I represent a paragraph of text"".

For the Responsibility part: Three sentences about my main responsibilities - what I do, what I know.

For the Collaborators Part: State my main collaborators and one line about how I interact with them. 

Public API and Key Messages

- message one   
- message two 
- (for bonus points) how to create instances.

   One simple example is simply gorgeous.
 
Internal Representation and Key Implementation Points.


    Implementation Points
"
Class {
	#name : 'BaselineOfMooseRestAPI',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfMooseRestAPI',
	#package : 'BaselineOfMooseRestAPI'
}

{ #category : 'baselines' }
BaselineOfMooseRestAPI >> baseline: spec [
	<baseline>
	spec
		for: #common
		do: [ 
			self defineDependencies: spec.
			self definePackages: spec.
			self defineGroups: spec ]
]

{ #category : 'baselines' }
BaselineOfMooseRestAPI >> defineDependencies: spec [

	spec
		baseline: 'Tealight'
		with: [ spec repository: 'github://astares/Tealight/repository' ].
	spec baseline: 'NeoJSON' with: [
			spec
				repository: 'github://svenvc/NeoJSON';
				loads: #( 'core' ) ]
]

{ #category : 'baselines' }
BaselineOfMooseRestAPI >> defineGroups: spec [
	"Note: no 'Moose-GraphQL' group is declared because a group cannot share
	its name with a package in Metacello; loading 'Moose-GraphQL' targets the package directly."

	spec
		group: 'GraphQL' with: #( 'GraphQL-Core' );
		group: 'GraphQL-Tests' with: #( 'GraphQL-Core-Tests' );
		group: 'Tests'
		with: #( 'GraphQL-Core-Tests' 'Moose-GraphQL-Tests' );
		group: 'default'
		with: #( 'Moose-REST-API' 'Moose-REST-API-Generator'
			   'GraphQL-Core' 'GraphQL-Core-Tests' 'Moose-GraphQL'
			   'Moose-GraphQL-Tests' )
]

{ #category : 'baselines' }
BaselineOfMooseRestAPI >> definePackages: spec [

	spec
		package: 'Moose-REST-API'
		with: [ spec requires: #( 'Tealight' ) ].
	spec
		package: 'Moose-REST-API-Generator'
		with: [ spec requires: #( 'Moose-REST-API' ) ].
	spec package: 'GraphQL-Core' with: [ spec requires: #( 'NeoJSON' ) ].
	spec
		package: 'GraphQL-Core-Tests'
		with: [ spec requires: #( 'GraphQL-Core' ) ].
	spec
		package: 'Moose-GraphQL'
		with: [ spec requires: #( 'GraphQL-Core' ) ].
	spec
		package: 'Moose-GraphQL-Tests'
		with: [ spec requires: #( 'Moose-GraphQL' ) ]
]
