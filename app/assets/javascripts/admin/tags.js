$(document).ready(function() {
  $("#service_keywords,#organization_accreditations,#organization_licenses,#select2_tags").select2({
    tags: [''],
    tokenSeparators: [',']
  });
});
