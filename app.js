function initExtras(){
    if( $.duration['/init'] < 1700 ) // on fast connections
        $.components.push('https://fonts.googleapis.com/css?family=Raleway')
}

function initButton(){
    var $btn = $('#convert')
    $btn.addEventListener('click', function(e){
        var a = $('.tablet').innerHTML        
        var b = $('template#code').innerHTML        
        $('.tablet').innerHTML = b
        $('template#code').innerHTML = a
    })
}

function initMarkdown(key, url){
  if( ! url.match( new RegExp( key+"\.md$") ) ) return // not interested
  var $ref = $('div#'+key)
  $ref.innerHTML = marked( $ref.innerHTML )
}

$.sub('/route/change',  function(e){
  if( e.hidden ) return $.showCard( 'Not in menu' ) // triggered by index.html?hidden=true
  $.pub('/menu/change', {target:$('#menu select')}) // default routing behaviour 
})

$.sub('/init', 			[initExtras]  )
$.sub('/init/done', 	[initButton] )
$.sub('/menu/change', 	[console.dir] )
$.sub('/request/done',  [ 
  initMarkdown.bind(window,'reference'), 
  initMarkdown.bind(window,'why'), 
  initMarkdown.bind(window,'FAQ'), 
  initMarkdown.bind(window,'modules-example'), 
  initMarkdown.bind(window,'json'), 
])     

