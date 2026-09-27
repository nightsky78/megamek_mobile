package megamekmobile.bridge.dto;

import java.util.List;

public record BoardDto(int boardId, int width, int height, List<HexDto> hexes) {
}
