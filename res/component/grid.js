window.paperapp.elements.grid = function(opts){
    var el = $.Element({
        attr: {
            class:"grid"  
        }
    })

    opts.items.map( function(i){
      el.appendChild( $.Element({
        style: Object.assign( opts.style || {},{
            float:"left",
            backgroundImage: "url("+i+")",
            backgroundSize:"contain",
            backgroundPosition:"center",
            backgroundRepeat:"no-repeat",
            margin:'0px 20px 20px 0px'
        })
      }))  
    })

    el.appendChild( $.Element({
        style:{
            "clear":"both"
        }
    }))

    return el
}
