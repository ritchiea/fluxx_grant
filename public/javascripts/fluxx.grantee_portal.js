(function($){
  $.fn.extend({
		installFluxxDecorators: function() {
		  $.each($.fluxx.decorators, function(key,val) {
		    $(key).live.apply($(key), val);
		  });
		},
		loadTable: function($table, pageIncrement) {
			$table.attr('data-src', $table.attr('data-src').replace(/page=(\d+)/, function(a,b){
			  var page = parseInt(b) + pageIncrement;
			  return 'page=' + page;
			}));
			$.ajax({
              url: $table.attr('data-src'),
		      success: function(data, status, xhr){
				$table.html(data);
              }
            });
		}
	});
	
	$.extend(true, {
		fluxx: {
		  decorators: {
	      'a.prev-page': [
	        'click', function(e) {          
                e.preventDefault();
                var $elem = $(this);
                if ($elem.hasClass('disabled'))
                    return;
                var $area = $elem.parents('.content');
                    $.fn.loadTable($area, -1);
	        }
	      ],
	      'a.next-page': [
	        'click', function(e) {          
                e.preventDefault();
                var $elem = $(this);
                if ($elem.hasClass('disabled'))
                    return;
                var $area = $elem.parents('.content');
                $.fn.loadTable($area, 1);
	        }
	      ],
          'tbody' : [
		    'click', function(e) {
                e.preventDefault();
                var $elem = $(this);
                var url = $elem.attr('data-url');
                if (url)
                        window.location = url;
            }
		  ],
          'a.to-upload': [
            'click', function(e) {
              e.preventDefault();
              var $elem = $(this);
              $.modal('<div class="upload-queue"></div>', {
                minWidth: 700,
                minHeight: 400,
                closeHTML: '<span>Close</span>',
                close: true,
                closeOverlay: true,
                escClose:true,
                opacity: 50,
                onShow: function () {
                  $('.upload-queue').pluploadQueue({
                    url: $elem.attr('href'),
                    runtimes: 'html5',
                    multipart: false,
                    filters: [{title: "Allowed file types", extensions: $elem.attr('data-extensions')}]
                  });
                },
                onClose: function(){
                  var $area = $('.reports').first();
                  $.fn.loadTable($area, 0);
                  $.modal.close();
                }
              });
            }
          ],
          'a.submit-report': [
            'click', function(e) {
              e.preventDefault();
              var $elem = $(this);
              var $area = $elem.parents('.content');
              $.ajax({
                url: $elem.attr('href'),
                type: 'PUT',
                data: {},
		        success: function(data, status, xhr){
				  $.fn.loadTable($area, 0);
                }
              });
            }
          ],
          'a.as-delete': [
            'click', function(e) {
              e.preventDefault();
              var $elem = $(this);
              var $area = $elem.parents('.content');
              if (confirm('This request will be deleted. Are you sure?'))
                $.ajax({
                  url: $elem.attr('href'),
                  type: 'DELETE',
		          success: function(data, status, xhr){
				    $.fn.loadTable($area, 0);
                  }
                });
            }
          ]
		 }
	    }
	});
})(jQuery);

$(document).ready(function() {
	$.fn.installFluxxDecorators();
});