using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class HaftalikOzet : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "HaftalikOzetler",
                columns: table => new
                {
                    Hafta = table.Column<DateOnly>(type: "date", nullable: false),
                    YazilmaAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HaftalikOzetler", x => x.Hafta);
                });

            migrationBuilder.CreateTable(
                name: "HatirlaticiOlaylari",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HatirlaticiId = table.Column<Guid>(type: "uuid", nullable: false),
                    Tur = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    HedefAn = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    Zaman = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HatirlaticiOlaylari", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_HatirlaticiOlaylari_Zaman",
                table: "HatirlaticiOlaylari",
                column: "Zaman");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "HaftalikOzetler");

            migrationBuilder.DropTable(
                name: "HatirlaticiOlaylari");
        }
    }
}
