$(function(){
  var searchIndex = lunr(function() {
    this.ref('url');
    this.field('name');
  });

  var $typeahead = $('[data-typeahead]');
  var $form = $typeahead.parents('form');
  var searchURL = $form.attr('action');

  function displayTemplate(result) {
    return result.name;
  }

  function suggestionTemplate(result) {
    var t = '<div class="list-group-item clearfix">';
    t += '<span class="doc-name">' + result.name + '</span>';
    if (result.parent_name) {
     t += '<span class="doc-parent-name label">' + result.parent_name + '</span>';
    }
    t += '</div>';
    return t;
  }

  $typeahead.one('focus', function() {
    $form.addClass('loading');

    $.getJSON(searchURL).then(function(searchData) {
      $.each(searchData, function (url, doc) {
        searchIndex.add({url: url, name: doc.name});
      });

      $typeahead.typeahead(
        {
          highlight: true,
          minLength: 3
        },
        {
          limit: 10,
          display: displayTemplate,
          templates: { suggestion: suggestionTemplate },
          source: function(query, sync) {
            var results = searchIndex.search(query).map(function(result) {
              var doc = searchData[result.ref];
              doc.url = result.ref;
              return doc;
            });
            sync(results);
          }
        }
      );
      $form.removeClass('loading');
      $typeahead.trigger('focus');
    });
  });

  $typeahead.on('typeahead:select', function(e, result) {
    var subdirectory = window.location.pathname.split('/').slice(0, -1).pop();
    var jazzySubdirectories = ['Categories', 'Classes', 'Enums', 'Protocols', 'Structs'];
    if (jazzySubdirectories.indexOf(subdirectory) > -1) {
      result.url = ('../').concat(result.url);
    }
    window.location = result.url;
  });
});