module JqgridJson
  def to_jqgrid_json(attributes, current_page, per_page, total)
    json = %Q({"page":"#{current_page}","total":#{total/per_page.to_i+1},"records":"#{total}","rows":[)

    each do |elem|
      json << %Q({"id":"#{elem.id}","cell":[)
      couples = elem.attributes.symbolize_keys
      attributes.each do |atr|
        value = couples[atr]
        association = atr.to_s.split('.')
        case association.length
        when 1
          value = elem.send(association[0].to_sym) if elem.respond_to?(atr) && value.blank?
        when 2
          value = elem.send(association[0].to_sym).andand.send(association[1].to_sym) if association[0] && value.blank?
        when 3
          value = elem.send(association[0].to_sym).send(association[1].to_sym).send(association[2].to_sym) if association[0] && association[1] && value.blank?
        end
        json << %Q("#{value}",)
      end
      json.chop! << "]},"
    end
    json.chop! << "]}"
  end

end

class Array
  include JqgridJson
end
